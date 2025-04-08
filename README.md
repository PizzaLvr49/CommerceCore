# PurchaseHandler Module

The **PurchaseHandler** module is a robust solution for managing in-game currencies, purchases, gamepasses, and subscriptions with support for Roblox’s Developer Products. It provides a promise-based workflow, signals for event handling, and separate registration functions to handle both Robux-based and money subscriptions.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Installation](#installation)
- [Module Structure](#module-structure)
- [API Reference](#api-reference)
  - [Currency Management](#currency-management)
  - [Developer Product Purchases](#developer-product-purchases)
  - [Gamepass Purchases](#gamepass-purchases)
  - [Subscription Purchases](#subscription-purchases)
  - [Separate Subscription Functions](#separate-subscription-functions)
- [Usage Examples](#usage-examples)
- [Integration with Player Data](#integration-with-player-data)
- [Signal Handling](#signal-handling)
- [Troubleshooting](#troubleshooting)
- [License](#license)

## Overview

The **PurchaseHandler** module integrates in-game currency management with Roblox’s purchasing systems. It leverages a promise-based approach to handle asynchronous transactions, supports multiple transaction types simultaneously, and integrates with a ProfileService to store and retrieve player data.

## Features

- **Currency Management:**  
  - Register currencies with display names, abbreviations, and default values.
  - Add and deduct in-game currencies.
  - Format currency displays.

- **Custom Developer Product Purchases:**  
  - Register custom purchases using Roblox Developer Products.
  - Promise-based purchase flows with timeouts and error handling.

- **Gamepass Integration:**  
  - Register and handle Gamepass purchases.
  - Listen to purchase events and apply in-game benefits.

- **Subscription Integration:**  
  - Generic subscription functionality using Developer Products.
  - Separately manage Robux subscriptions (for Robux-based benefits) and money subscriptions (for premium in‑game currencies) with separate registration functions.
  - Prevent multiple simultaneous subscription transactions using active flags.

- **Signal System:**  
  - Event signals for currency added, currency deducted, purchase completed, purchase failed, and profile loaded.

## Installation

1. **ProfileService & Signal Modules:**  
   Ensure that you have the required dependencies. Place your `ProfileService` and `Signal` modules inside the appropriate directory (e.g., `ServerStorage/Modules/`).

2. **PurchaseHandler Module:**  
   Place `PurchaseHandler.lua` (the file containing the updated module code) in your modules folder, for example:  
   ```
   ServerStorage/Modules/PurchaseHandler.lua
   ```

3. **Configure Developer Products and Gamepasses:**  
   Set the proper Product IDs and Gamepass IDs inside the module registrations (or when calling the registration functions).

## Module Structure

The **PurchaseHandler** module organizes functionality into several sections:

- **Currency Management:**  
  Handles currency registrations, balance queries, and currency adjustments.

- **Purchase Functions:**  
  Contains custom purchase registration functions that use Developer Products.

- **Gamepass Purchases:**  
  Functions to register and handle gamepass transactions.

- **Subscription Purchases:**  
  Contains both a generic subscription registration and separate functions for handling Robux and Money subscriptions.

- **Promise Implementation:**  
  Uses an internal promise system to manage asynchronous purchase flows with timeout support.

- **Player Data Management:**  
  Initializes and stores player profiles and ensures currency values are reconciled when players join.

## API Reference

### Currency Management

- **`RegisterCurrency(currencyId, options)`**  
  Registers a new currency. Options include:
  - `DisplayName`: Friendly name.
  - `Abbreviation`: A short string or symbol.
  - `AbbreviationPrefix`: Boolean indicating whether the abbreviation is prefixed or suffixed.
  - `DefaultValue`: Starting balance.
  - `PurchaseIDs`: A table mapping currency amounts to Developer Product IDs.

- **`GetCurrency(player, currencyId)`**  
  Returns the current balance for a player.

- **`AddCurrency(player, currencyId, amount)`**  
  Increases the player’s currency balance.

- **`DeductCurrency(player, currencyId, amount)`**  
  Deducts currency if available, fires related signals if successful.

### Developer Product Purchases

- **`RegisterCustomPurchase(name, purchaseID, customCallback, isPurchasedCallback)`**  
  Registers a custom purchase using a Developer Product and triggers callbacks upon purchase completion or cancellation.

- **`RegisterRobuxPurchase(currencyId, amount, productId)`**  
  Registers a Developer Product purchase for a specific currency.

### Gamepass Purchases

- **`RegisterGamepassPurchase(name, gamepassId, gamepassCallback, isPurchasedCallback)`**  
  Registers a gamepass-based purchase. Uses Roblox’s `PromptGamePassPurchase` and corresponding finished event.  
  - Use this function to grant permanent or special gamepass benefits.

### Subscription Purchases

#### Generic Subscription

- **`RegisterSubscriptionPurchase(name, productId, subscriptionCallback, isPurchasedCallback)`**  
  Registers a generic subscription purchase.  
  - The callback functions are used to provide benefits upon successful purchase.

#### Separate Subscription Functions

- **`RegisterRobuxSubscriptionPurchase(name, productId, subscriptionCallback, isPurchasedCallback)`**  
  Registers a subscription that grants Robux-based benefits. It uses its own active transaction flag (`robuxSubscription`).

- **`RegisterMoneySubscriptionPurchase(name, productId, subscriptionCallback, isPurchasedCallback)`**  
  Registers a subscription that grants in‑game premium currency benefits. This function uses a separate active flag (`moneySubscription`).

### Purchase Flow Execution

- **`ExecuteImmediatePurchase(purchase, player, ...)`**  
  Executes a purchase immediately in a promise-based fashion.

- **`PromptCurrencyPurchase(currencyId, amount, player, callback)`**  
  Prompts a purchase for a currency amount using the registered purchase functions.

### Marketplace Service Integration

- **`ProcessReceipt(receiptInfo)`**  
  Processes completed Developer Product receipts (required for Roblox Developer Products).

## Usage Examples

### Registering a Currency

```lua
PurchaseHandler.RegisterCurrency("Cash", {
    DisplayName = "Cash",
    Abbreviation = "$",
    AbbreviationPrefix = true,
    DefaultValue = 100,
    PurchaseIDs = {
        [100] = 12345678,  -- Developer Product ID for 100 Cash
        [1000] = 12345679  -- Developer Product ID for 1000 Cash
    }
})
```

### Registering Custom Purchases (e.g., VIP Purchase)

```lua
PurchaseHandler.RegisterCustomPurchase(
    "VIPPass",
    12345681,
    function(userId)
        local player = Players:GetPlayerByUserId(userId)
        if not player then return false end
        PurchaseHandler.AddCurrency(player, "Cash", 1000)
        PurchaseHandler.AddCurrency(player, "Gems", 100)
        player:SetAttribute("IsVIP", true)
        return true
    end
)
```

### Registering Gamepass and Subscriptions

```lua
-- Gamepass purchase for a permanent speed boost
PurchaseHandler.RegisterGamepassPurchase(
    "SpeedBoostGamepass",
    23456789,
    function(userId)
        local player = Players:GetPlayerByUserId(userId)
        if player and player.Character then
            player.Character.Humanoid.WalkSpeed = 32
            return true
        end
        return false
    end,
    function(userId, isPurchased, errMsg)
        print("Gamepass purchase status for", userId, isPurchased, errMsg)
    end
)

-- Robux subscription purchase
PurchaseHandler.RegisterRobuxSubscriptionPurchase(
    "MonthlyRobuxSubscription",
    34567890,
    function(userId)
        local player = Players:GetPlayerByUserId(userId)
        if player then
            PurchaseHandler.AddCurrency(player, "Cash", 500)
            return true
        end
        return false
    end,
    function(userId, isPurchased, errMsg)
        print("Robux subscription status for", userId, isPurchased, errMsg)
    end
)

-- Money subscription purchase
PurchaseHandler.RegisterMoneySubscriptionPurchase(
    "MonthlyMoneySubscription",
    45678901,
    function(userId)
        local player = Players:GetPlayerByUserId(userId)
        if player then
            PurchaseHandler.AddCurrency(player, "Gems", 10)
            player:SetAttribute("IsSubscriber", true)
            return true
        end
        return false
    end,
    function(userId, isPurchased, errMsg)
        print("Money subscription status for", userId, isPurchased, errMsg)
    end
)
```

### Executing Purchases

A typical flow to execute a purchase immediately:

```lua
local vipPurchase = PurchaseHandler.GetPurchase("VIPPass")
vipPurchase(player)
```

Or prompt a currency purchase:

```lua
PurchaseHandler.PromptCurrencyPurchase("Cash", 100, player, function(success, errMsg)
    if success then
        print("Cash purchase successful!")
    else
        warn("Cash purchase failed:", errMsg)
    end
end)
```

## Integration with Player Data

- **Player Joining/Leaving:**  
  The module utilizes a `ProfileService` to load player data on join and reconcile currency balances.  
  - When the player joins, their profile is loaded and any missing currency is initialized to its default value.
  - On leaving, the profile data is released, ensuring no duplicate data conflicts.

## Signal Handling

The module emits various signals which you can connect to for handling different events:

- `CurrencyAdded` – Fired when a currency is increased.
- `CurrencyDeducted` – Fired when a currency is deducted.
- `PurchaseCompleted` – Fired when a purchase completes successfully.
- `PurchaseFailed` – Fired when a purchase fails or is cancelled.
- `ProfileLoaded` – Fired when a player’s profile is successfully loaded.

Example:

```lua
PurchaseHandler.Signals.CurrencyAdded:Connect(function(player, currencyId, amount)
    print(player.Name .. " received " .. amount .. " " .. currencyId)
end)
```

## Troubleshooting

- **Timeouts:**  
  If a purchase times out, check that the appropriate product or gamepass IDs are set up correctly in your Roblox game and that there is no conflict in active transaction flags.

- **Profile Issues:**  
  If a player's profile is not loading correctly, ensure that ProfileService is properly configured and that the storage key is unique.

- **Multiple Transactions:**  
  The module prevents duplicate simultaneous transactions for the same type by using active flags. If a purchase is not completing, check if a previous transaction is still active.

## License

[License](LICENSE)
