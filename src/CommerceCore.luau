local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProfileService = require(script.Parent.ProfileService)
local Signal = require(script.Parent.Signal)

--[[
    CommerceCore Module
    Simple module for currencies and purchases with signal support.
]]

local CommerceCore = {}

-- Constants
local PROMPT_TIMEOUT = 60
local DEFAULT_AWAIT_TIMEOUT = 30

-- Private state
local currencyConfigs = {}
local namedPurchases = {}
local developerProductCallbacks = {}
local playerData = {}
local profileStore = nil

-- Signals
CommerceCore.Signals = {
	CurrencyAdded = Signal.new(),
	CurrencyDeducted = Signal.new(),
	PurchaseCompleted = Signal.new(),
	PurchaseFailed = Signal.new(),
	ProfileLoaded = Signal.new()
}

-- Profile template
local ProfileTemplate = {
	Currencies = {}
}

-- Initialize player data structure
local function initPlayerData(userId)
	if not playerData[userId] then
		playerData[userId] = {
			profile = nil,
			canTransact = true,
			activeTransactions = {
				regular = false,
				robux = false,
				gamepass = false,
				subscription = false,         -- generic subscription (if needed)
				robuxSubscription = false,    -- new flag for robux subscription
				moneySubscription = false     -- new flag for money subscription
			},
			purchaseQueue = {}
		}
	end
	return playerData[userId]
end

-- Initialize ProfileService
local function initProfileService()
	profileStore = ProfileService.GetProfileStore("PlayerCurrencies", ProfileTemplate)
end

-- Promise implementation
local function createPromise()
	local bindableEvent = Instance.new("BindableEvent")

	local promise = {
		completed = false,
		result = nil,
		errorMessage = nil,

		resolve = function(self, success, errorMsg)
			self.completed = true
			self.result = success
			self.errorMessage = errorMsg
			bindableEvent:Fire()
			bindableEvent:Destroy()
			return self
		end,

		await = function(self, timeout)
			if self.completed then
				return self.result, self.errorMessage
			end

			local complete = false
			if timeout then
				task.delay(timeout, function()
					if not complete then
						complete = true
						if not self.completed then
							self:resolve(false, "Timed out")
						end
					end
				end)

				bindableEvent.Event:Wait()
				complete = true
			else
				bindableEvent.Event:Wait()
			end

			return self.result, self.errorMessage
		end,

		catchTimeout = function(self, callback)
			if self.errorMessage == "Timed out" and callback then
				callback()
			end
			return self.result, self.errorMessage
		end
	}

	return promise
end

-- Process the next purchase in queue
local function processQueue(userId)
	local data = playerData[userId]
	if not data or not data.canTransact or data.activeTransactions.regular then
		return
	end

	local queue = data.purchaseQueue
	if #queue == 0 then
		return
	end

	local nextPurchase = table.remove(queue, 1)
	data.activeTransactions.regular = true

	task.spawn(function()
		pcall(function() 
			nextPurchase.func(unpack(nextPurchase.args))
		end)
		data.activeTransactions.regular = false
		processQueue(userId)
	end)
end

-- Queue a purchase function
local function queuePurchase(userId, purchaseFunc, args, highPriority)
	local data = initPlayerData(userId)

	local purchaseData = {
		func = purchaseFunc,
		args = args or {}
	}

	if highPriority then
		table.insert(data.purchaseQueue, 1, purchaseData)
	else
		table.insert(data.purchaseQueue, purchaseData)
	end

	processQueue(userId)
end

--[[
    Currency Management
]]

-- Register a new currency
function CommerceCore.RegisterCurrency(currencyId, options)
	options = options or {}

	if currencyConfigs[currencyId] then
		warn("Currency", currencyId, "already exists!")
		return currencyId
	end

	currencyConfigs[currencyId] = {
		DisplayName = options.DisplayName or currencyId,
		Abbreviation = options.Abbreviation or currencyId,
		AbbreviationPrefix = options.AbbreviationPrefix or false,
		DefaultValue = options.DefaultValue or 0,
		PurchaseIDs = options.PurchaseIDs or {}
	}

	-- Register purchase IDs if provided
	if options.PurchaseIDs then
		for amount, productId in pairs(options.PurchaseIDs) do
			CommerceCore.RegisterRobuxPurchase(currencyId, amount, productId)
		end
	end

	-- Initialize for existing players
	for userId, data in pairs(playerData) do
		if data.profile and data.profile.Data.Currencies[currencyId] == nil then
			data.profile.Data.Currencies[currencyId] = currencyConfigs[currencyId].DefaultValue
		end
	end

	return currencyId
end

-- Get currency display name
function CommerceCore.GetCurrencyDisplayName(currencyId)
	if not currencyConfigs[currencyId] then return currencyId end
	return currencyConfigs[currencyId].DisplayName
end

-- Format a currency amount with its abbreviation
function CommerceCore.FormatCurrency(currencyId, amount)
	local config = currencyConfigs[currencyId]
	if not config then return tostring(amount) end

	if config.AbbreviationPrefix then
		return config.Abbreviation .. amount
	else
		return amount .. config.Abbreviation
	end
end

-- Get a player's currency amount
function CommerceCore.GetCurrency(player, currencyId)
	if not player then return 0 end
	if not currencyConfigs[currencyId] then return 0 end

	local userId = player.UserId
	local data = playerData[userId]

	if not data or not data.profile then return 0 end

	return data.profile.Data.Currencies[currencyId] or currencyConfigs[currencyId].DefaultValue
end

-- Set a player's currency amount directly
function CommerceCore.SetCurrency(player, currencyId, amount)
	if not player or not currencyConfigs[currencyId] then return false end

	local data = playerData[player.UserId]
	if not data or not data.profile then return false end

	-- Initialize if needed
	if data.profile.Data.Currencies[currencyId] == nil then
		data.profile.Data.Currencies[currencyId] = currencyConfigs[currencyId].DefaultValue
	end

	local oldAmount = data.profile.Data.Currencies[currencyId]
	local success = pcall(function()
		data.profile.Data.Currencies[currencyId] = amount
	end)

	if success and amount > oldAmount then
		CommerceCore.Signals.CurrencyAdded:Fire(player, currencyId, amount - oldAmount)
	end

	return success
end

-- Add currency to a player's balance
function CommerceCore.AddCurrency(player, currencyId, amount)
	if not player or not currencyConfigs[currencyId] then return false end

	local data = playerData[player.UserId]
	if not data or not data.profile then return false end

	if data.profile.Data.Currencies[currencyId] == nil then
		data.profile.Data.Currencies[currencyId] = currencyConfigs[currencyId].DefaultValue
	end

	local success = pcall(function()
		data.profile.Data.Currencies[currencyId] += amount
	end)

	if success then
		CommerceCore.Signals.CurrencyAdded:Fire(player, currencyId, amount)
	end

	return success
end

-- Deduct currency if they have enough
function CommerceCore.DeductCurrency(player, currencyId, amount)
	if not player then return false, "Invalid player" end
	if not currencyConfigs[currencyId] then return false, "Unknown currency" end
	if amount <= 0 then return false, "Amount must be positive" end

	local data = playerData[player.UserId]
	if not data or not data.profile then return false, "No profile" end

	if data.profile.Data.Currencies[currencyId] == nil then
		data.profile.Data.Currencies[currencyId] = currencyConfigs[currencyId].DefaultValue
	end

	-- Check if player has enough
	if data.profile.Data.Currencies[currencyId] < amount then
		return false, "Not enough " .. currencyConfigs[currencyId].DisplayName
	end

	local success, err = pcall(function()
		data.profile.Data.Currencies[currencyId] -= amount
	end)

	if success then
		CommerceCore.Signals.CurrencyDeducted:Fire(player, currencyId, amount)
	end

	if not success then return false, err end
	return true
end

-- Check if a player has enough of a currency
function CommerceCore.HasCurrency(player, currencyId, amount)
	if not player then return false end
	local balance = CommerceCore.GetCurrency(player, currencyId)
	return balance >= amount
end

--[[
    Robux Purchase Functions
]]

-- Register a Custom Purchase with Robux
function CommerceCore.RegisterCustomPurchase(name, purchaseID, customCallback, isPurchasedCallback)
	if namedPurchases[name] then
		warn("Purchase '" .. name .. "' already exists!")
		return namedPurchases[name]
	end

	developerProductCallbacks[purchaseID] = customCallback

	namedPurchases[name] = function(player)
		local userId = player.UserId
		local data = playerData[userId]
		local promise = createPromise()

		-- Check if purchase in progress
		if data.activeTransactions.robux then
			promise:resolve(false, "Purchase already in progress")
			return promise
		end

		-- Mark purchase in progress
		data.activeTransactions.robux = true

		task.spawn(function()
			-- Prompt purchase
			MarketplaceService:PromptProductPurchase(player, purchaseID)

			-- Listen for completion
			local conn
			conn = MarketplaceService.PromptProductPurchaseFinished:Connect(function(pUserId, pId, isPurchased)
				if pUserId == userId and pId == purchaseID then
					local errMsg = isPurchased and "" or "Purchase cancelled"

					if isPurchasedCallback then
						isPurchasedCallback(userId, isPurchased, errMsg)
					end

					if isPurchased then
						CommerceCore.Signals.PurchaseCompleted:Fire(player, purchaseID, name)
					else
						CommerceCore.Signals.PurchaseFailed:Fire(player, purchaseID, name, errMsg)
					end

					promise:resolve(isPurchased, errMsg)
					data.activeTransactions.robux = false
					conn:Disconnect()
				end
			end)

			-- Timeout
			task.delay(PROMPT_TIMEOUT, function()
				if not promise.completed then
					if conn then conn:Disconnect() end
					promise:resolve(false, "Timed out")
					data.activeTransactions.robux = false
					CommerceCore.Signals.PurchaseFailed:Fire(player, purchaseID, name, "Timed out")
				end
			end)
		end)

		return promise
	end

	return namedPurchases[name]
end

-- Register a Robux purchase for a currency
function CommerceCore.RegisterRobuxPurchase(currencyId, amount, productId)
	if not currencyConfigs[currencyId] then
		warn("Can't register purchase: Currency", currencyId, "not found")
		return
	end

	local name = currencyId .. tostring(amount)

	CommerceCore.RegisterCustomPurchase(name, productId, function(userId)
		local player = Players:GetPlayerByUserId(userId)
		if not player then return false end

		local data = playerData[userId]
		if not data or not data.profile then return false end

		if data.profile.Data.Currencies[currencyId] == nil then
			data.profile.Data.Currencies[currencyId] = currencyConfigs[currencyId].DefaultValue
		end

		data.profile.Data.Currencies[currencyId] += amount
		CommerceCore.Signals.CurrencyAdded:Fire(player, currencyId, amount)
		return true
	end)
end

-- Register a Gamepass purchase
function CommerceCore.RegisterGamepassPurchase(name, gamepassId, gamepassCallback, isPurchasedCallback)
	if namedPurchases[name] then
		warn("Purchase '" .. name .. "' already exists!")
		return namedPurchases[name]
	end

	namedPurchases[name] = function(player)
		local userId = player.UserId
		local data = playerData[userId]
		local promise = createPromise()

		-- Check if a gamepass transaction is in progress
		if data.activeTransactions.gamepass then
			promise:resolve(false, "Purchase already in progress")
			return promise
		end

		data.activeTransactions.gamepass = true

		task.spawn(function()
			-- Prompt gamepass purchase
			MarketplaceService:PromptGamePassPurchase(player, gamepassId)

			-- Listen for completion
			local conn
			conn = MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(pPlayer, pGamepassId, isPurchased)
				if pPlayer == player and pGamepassId == gamepassId then
					local errMsg = isPurchased and "" or "Purchase cancelled"

					if isPurchasedCallback then
						isPurchasedCallback(userId, isPurchased, errMsg)
					end

					if isPurchased and gamepassCallback then
						gamepassCallback(userId)
						CommerceCore.Signals.PurchaseCompleted:Fire(player, gamepassId, name)
					else
						CommerceCore.Signals.PurchaseFailed:Fire(player, gamepassId, name, errMsg)
					end

					promise:resolve(isPurchased, errMsg)
					data.activeTransactions.gamepass = false
					conn:Disconnect()
				end
			end)

			-- Timeout
			task.delay(PROMPT_TIMEOUT, function()
				if not promise.completed then
					if conn then conn:Disconnect() end
					promise:resolve(false, "Timed out")
					data.activeTransactions.gamepass = false
					CommerceCore.Signals.PurchaseFailed:Fire(player, gamepassId, name, "Timed out")
				end
			end)
		end)

		return promise
	end

	return namedPurchases[name]
end

-- Register a Subscription purchase (generic, if needed)
function CommerceCore.RegisterSubscriptionPurchase(name, productId, subscriptionCallback, isPurchasedCallback)
	if namedPurchases[name] then
		warn("Purchase '" .. name .. "' already exists!")
		return namedPurchases[name]
	end

	developerProductCallbacks[productId] = subscriptionCallback

	namedPurchases[name] = function(player)
		local userId = player.UserId
		local data = playerData[userId]
		local promise = createPromise()

		-- Check if a subscription transaction is in progress
		if data.activeTransactions.subscription then
			promise:resolve(false, "Purchase already in progress")
			return promise
		end

		data.activeTransactions.subscription = true

		task.spawn(function()
			MarketplaceService:PromptProductPurchase(player, productId)

			local conn
			conn = MarketplaceService.PromptProductPurchaseFinished:Connect(function(pUserId, pId, isPurchased)
				if pUserId == userId and pId == productId then
					local errMsg = isPurchased and "" or "Purchase cancelled"

					if isPurchasedCallback then
						isPurchasedCallback(userId, isPurchased, errMsg)
					end

					if isPurchased then
						CommerceCore.Signals.PurchaseCompleted:Fire(player, productId, name)
					else
						CommerceCore.Signals.PurchaseFailed:Fire(player, productId, name, errMsg)
					end

					promise:resolve(isPurchased, errMsg)
					data.activeTransactions.subscription = false
					conn:Disconnect()
				end
			end)

			task.delay(PROMPT_TIMEOUT, function()
				if not promise.completed then
					if conn then conn:Disconnect() end
					promise:resolve(false, "Timed out")
					data.activeTransactions.subscription = false
					CommerceCore.Signals.PurchaseFailed:Fire(player, productId, name, "Timed out")
				end
			end)
		end)

		return promise
	end

	return namedPurchases[name]
end

--[[
   New Functions: Separate Module Functions for Robux and Money Subscriptions
]]

-- Register a Robux Subscription purchase
function CommerceCore.RegisterRobuxSubscriptionPurchase(name, productId, subscriptionCallback, isPurchasedCallback)
	if namedPurchases[name] then
		warn("Purchase '" .. name .. "' already exists!")
		return namedPurchases[name]
	end

	-- Store the callback for this product ID
	developerProductCallbacks[productId] = subscriptionCallback

	namedPurchases[name] = function(player)
		local userId = player.UserId
		local data = playerData[userId]
		local promise = createPromise()

		-- Check if a robux subscription is already in progress
		if data.activeTransactions.robuxSubscription then
			promise:resolve(false, "Robux subscription already in progress")
			return promise
		end

		data.activeTransactions.robuxSubscription = true

		task.spawn(function()
			MarketplaceService:PromptProductPurchase(player, productId)

			local conn
			conn = MarketplaceService.PromptProductPurchaseFinished:Connect(function(pUserId, pId, isPurchased)
				if pUserId == userId and pId == productId then
					local errMsg = isPurchased and "" or "Purchase cancelled"
					if isPurchasedCallback then
						isPurchasedCallback(userId, isPurchased, errMsg)
					end

					if isPurchased then
						CommerceCore.Signals.PurchaseCompleted:Fire(player, productId, name)
					else
						CommerceCore.Signals.PurchaseFailed:Fire(player, productId, name, errMsg)
					end

					promise:resolve(isPurchased, errMsg)
					data.activeTransactions.robuxSubscription = false
					conn:Disconnect()
				end
			end)

			task.delay(PROMPT_TIMEOUT, function()
				if not promise.completed then
					if conn then conn:Disconnect() end
					promise:resolve(false, "Timed out")
					data.activeTransactions.robuxSubscription = false
					CommerceCore.Signals.PurchaseFailed:Fire(player, productId, name, "Timed out")
				end
			end)
		end)

		return promise
	end

	return namedPurchases[name]
end

-- Register a Money Subscription purchase
function CommerceCore.RegisterMoneySubscriptionPurchase(name, productId, subscriptionCallback, isPurchasedCallback)
	if namedPurchases[name] then
		warn("Purchase '" .. name .. "' already exists!")
		return namedPurchases[name]
	end

	-- Store the callback for this product ID.
	developerProductCallbacks[productId] = subscriptionCallback

	namedPurchases[name] = function(player)
		local userId = player.UserId
		local data = playerData[userId]
		local promise = createPromise()

		-- Check if a money subscription is already in progress
		if data.activeTransactions.moneySubscription then
			promise:resolve(false, "Money subscription already in progress")
			return promise
		end

		data.activeTransactions.moneySubscription = true

		task.spawn(function()
			MarketplaceService:PromptProductPurchase(player, productId)

			local conn
			conn = MarketplaceService.PromptProductPurchaseFinished:Connect(function(pUserId, pId, isPurchased)
				if pUserId == userId and pId == productId then
					local errMsg = isPurchased and "" or "Purchase cancelled"
					if isPurchasedCallback then
						isPurchasedCallback(userId, isPurchased, errMsg)
					end

					if isPurchased then
						CommerceCore.Signals.PurchaseCompleted:Fire(player, productId, name)
					else
						CommerceCore.Signals.PurchaseFailed:Fire(player, productId, name, errMsg)
					end

					promise:resolve(isPurchased, errMsg)
					data.activeTransactions.moneySubscription = false
					conn:Disconnect()
				end
			end)

			task.delay(PROMPT_TIMEOUT, function()
				if not promise.completed then
					if conn then conn:Disconnect() end
					promise:resolve(false, "Timed out")
					data.activeTransactions.moneySubscription = false
					CommerceCore.Signals.PurchaseFailed:Fire(player, productId, name, "Timed out")
				end
			end)
		end)

		return promise
	end

	return namedPurchases[name]
end

-- Execute a purchase immediately
function CommerceCore.ExecuteImmediatePurchase(purchase, player, ...)
	if not player then
		local failPromise = createPromise()
		failPromise:resolve(false, "No player")
		return failPromise
	end

	if typeof(purchase) ~= "function" then
		local failPromise = createPromise()
		failPromise:resolve(false, "Invalid purchase")
		return failPromise
	end

	local promise = createPromise()
	local args = {...}

	task.spawn(function()
		local purchasePromise = purchase(player, unpack(args))

		if purchasePromise and typeof(purchasePromise) == "table" and typeof(purchasePromise.await) == "function" then
			local result, err = purchasePromise:await(DEFAULT_AWAIT_TIMEOUT)
			promise:resolve(result, err)
		else
			promise:resolve(true)
		end
	end)

	return promise
end

-- Prompt a currency purchase
function CommerceCore.PromptCurrencyPurchase(currencyId, amount, player, callback)
	if not currencyConfigs[currencyId] then
		if callback then callback(false, "Currency not found") end
		return false, "Currency not found"
	end

	local purchaseName = currencyId .. tostring(amount)
	local purchase = CommerceCore.GetPurchase(purchaseName)

	if not purchase then
		if callback then callback(false, "Purchase not found") end
		return false, "Purchase not found"
	end

	local promise = purchase(player)
	local result, err = promise:await()

	if callback then callback(result, err) end
	return result, err
end

--[[
    Marketplace Service Integration
]]

-- Process developer product purchases
function CommerceCore.ProcessReceipt(receiptInfo)
	local userId = receiptInfo.PlayerId
	local data = playerData[userId]

	-- Check if player data exists
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if not data.canTransact then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local callback = developerProductCallbacks[receiptInfo.ProductId]
	if callback then
		local success = pcall(callback, userId)
		if not success then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
	else
		warn("No callback for product", receiptInfo.ProductId)
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

--[[
    Player Data Management
]]

-- Handle player joining
local function onPlayerAdded(player)
	local userId = player.UserId
	local data = initPlayerData(userId)

	local profile = profileStore:LoadProfileAsync("Player_" .. userId)
	if profile then
		profile:AddUserId(userId)
		profile:Reconcile()

		for currencyId, config in pairs(currencyConfigs) do
			if profile.Data.Currencies[currencyId] == nil then
				profile.Data.Currencies[currencyId] = config.DefaultValue
			end
		end

		data.profile = profile

		profile.Release = function()
			data.profile = nil
			player:Kick("Your data is being used elsewhere. Please rejoin.")
		end

		CommerceCore.Signals.ProfileLoaded:Fire(player)
	else
		player:Kick("Failed to load your data. Please try again.")
	end
end

-- Handle player leaving
local function onPlayerRemoving(player)
	local data = playerData[player.UserId]
	if data and data.profile then
		data.profile:Release()
	end
	playerData[player.UserId] = nil
end

--[[
    Initialize
]]

local function init()
	initProfileService()

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Init existing players
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	MarketplaceService.ProcessReceipt = CommerceCore.ProcessReceipt
end

init()

return CommerceCore
