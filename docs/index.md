---
layout: default
title: Overview
nav_order: 1
---

# PurchaseHandler Module
{: .no_toc }

The `PurchaseHandler` module provides robust in-game currency, gamepass, and subscription handling using Roblox Developer Products with promise-based flows.

## Table of Contents
{: .no_toc }

1. TOC
{:toc}

---

## Features

### Currency Management
- Register, add, and deduct currencies
- Customize display names, symbols, prefixes
- Format currency amounts

### Developer Product Purchases
- Promise-based custom product flows
- Timeout and error handling
- Register Robux-backed currencies

### Gamepass Integration
- Register and handle Gamepass purchases
- Automatically apply benefits

### Subscription Management
- Separate Robux and premium currency subscriptions
- Use flags to avoid duplicate purchases

### Signal System
- Connect to events like currency updates and purchases

---

## Installation
{: #installation }

> 💡 **Dependencies:** Requires [`ProfileService`](https://eryn.io/roblox-lua-promise/api/ProfileService/) and a Signal module.

1. Place dependencies (e.g., `ProfileService.lua`, `Signal.lua`) in `ServerStorage/Modules/`
2. Place `PurchaseHandler.lua` in the same directory
3. Register product and gamepass IDs in your configuration

---

## Module Structure

- **Currency Management** – Register/query/add/deduct currency
- **Custom Purchases** – Handle Developer Products
- **Gamepass Integration** – Register gamepass transactions
- **Subscriptions** – Robux & Money subscriptions with callbacks
- **Promise System** – Used to handle async flows
- **Player Profiles** – Load/save player currency with ProfileService

---

## API Reference
{: #api-reference }

### Currency Management

```lua
PurchaseHandler.RegisterCurrency(currencyId, options)
```

**Options:**
- `DisplayName`: string
- `Abbreviation`: string
- `AbbreviationPrefix`: boolean
- `DefaultValue`: number
- `PurchaseIDs`: `{ [amount] = productId }`

```lua
local balance = PurchaseHandler.GetCurrency(player, currencyId)
PurchaseHandler.AddCurrency(player, currencyId, amount)
PurchaseHandler.DeductCurrency(player, currencyId, amount)
```

---

### Developer Product Purchases

```lua
PurchaseHandler.RegisterCustomPurchase(name, purchaseID, onSuccess, onCheck)
PurchaseHandler.RegisterRobuxPurchase(currencyId, amount, productId)
```

---

### Gamepass Purchases

```lua
PurchaseHandler.RegisterGamepassPurchase(name, gamepassId, onSuccess, onCheck)
```

---

### Subscriptions

#### Generic
```lua
PurchaseHandler.RegisterSubscriptionPurchase(name, productId, onSuccess, onCheck)
```

#### Robux
```lua
PurchaseHandler.RegisterRobuxSubscriptionPurchase(name, productId, onSuccess, onCheck)
```

#### Premium Currency
```lua
PurchaseHandler.RegisterMoneySubscriptionPurchase(name, productId, onSuccess, onCheck)
```

---

### Marketplace Integration

```lua
MarketplaceService.ProcessReceipt(receiptInfo)
```

---

## Usage Examples
{: #usage-examples }

### Currency Setup

```lua
PurchaseHandler.RegisterCurrency("Cash", {
  DisplayName = "Cash",
  Abbreviation = "$",
  AbbreviationPrefix = true,
  DefaultValue = 100,
  PurchaseIDs = {
    [100] = 12345678,
    [1000] = 12345679
  }
})
```

### Custom Purchase

```lua
PurchaseHandler.RegisterCustomPurchase("VIPPass", 12345681, function(userId)
  local player = Players:GetPlayerByUserId(userId)
  if player then
    PurchaseHandler.AddCurrency(player, "Cash", 1000)
    player:SetAttribute("IsVIP", true)
    return true
  end
  return false
end)
```

### Gamepass

```lua
PurchaseHandler.RegisterGamepassPurchase("SpeedBoost", 23456789, function(userId)
  local player = Players:GetPlayerByUserId(userId)
  if player and player.Character then
    player.Character.Humanoid.WalkSpeed = 32
    return true
  end
  return false
end)
```

---

## Player Data Integration

> ⚙️ ProfileService is used to load player data, and default currencies are reconciled upon join.

### Lifecycle

- **Join:** Profile loaded, defaults initialized
- **Leave:** Profile released

---

## Signal Events

```lua
PurchaseHandler.Signals.CurrencyAdded:Connect(function(player, currencyId, amount)
  print(player.Name .. " got " .. amount .. " " .. currencyId)
end)
```

Available signals:
- `CurrencyAdded`
- `CurrencyDeducted`
- `PurchaseCompleted`
- `PurchaseFailed`
- `ProfileLoaded`

---

## Troubleshooting

### Purchase Timeouts
Check:
- Product/Gamepass IDs are correct
- No transaction flags are stuck

### Profile Issues
- Ensure ProfileService is properly initialized
- Storage key must be unique

---

## License

[View License](LICENSE)
