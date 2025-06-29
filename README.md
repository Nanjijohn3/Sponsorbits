# Sponsorbit

A decentralized child sponsorship platform built on Stacks blockchain that connects sponsors directly with verified caregivers to support children in need.

## Overview

Sponsorbit enables transparent, direct funding from sponsors to verified caregivers responsible for children. All transactions are recorded on-chain, ensuring accountability and trust in the sponsorship process.

## Features

- **Caregiver Verification**: Only verified caregivers can register children
- **Direct Payments**: Funds go directly to caregiver wallets
- **Sponsorship Management**: One-to-one child-sponsor relationships
- **Transparent Tracking**: All donations and payments recorded on-chain
- **Admin Controls**: Contract owner can verify caregivers

## Contract Functions

### Registration Functions

#### `register-caregiver`
Registers a new caregiver (requires verification by admin before they can add children)
- **Parameters**: None
- **Returns**: `(response bool uint)`

#### `register-sponsor`
Registers a new sponsor account
- **Parameters**: None
- **Returns**: `(response bool uint)`

#### `register-child`
Registers a child under a verified caregiver
- **Parameters**: 
  - `name`: Child's name (string, max 50 chars)
  - `age`: Child's age (uint)
  - `location`: Child's location (string, max 100 chars)
  - `monthly-need`: Required monthly support amount (uint, in microSTX)
- **Returns**: `(response uint uint)` - Returns child ID on success

### Admin Functions

#### `verify-caregiver`
Verifies a registered caregiver (admin only)
- **Parameters**: `caregiver`: Principal of caregiver to verify
- **Returns**: `(response bool uint)`

### Sponsorship Functions

#### `create-sponsorship`
Creates a sponsorship relationship between sponsor and child
- **Parameters**:
  - `child-id`: ID of child to sponsor (uint)
  - `monthly-amount`: Amount to donate monthly (uint, in microSTX)
- **Returns**: `(response uint uint)` - Returns sponsorship ID on success

#### `make-payment`
Transfers monthly payment to child's caregiver
- **Parameters**: `sponsorship-id`: ID of sponsorship (uint)
- **Returns**: `(response bool uint)`

#### `deactivate-sponsorship`
Deactivates a sponsorship (sponsor only)
- **Parameters**: `sponsorship-id`: ID of sponsorship to deactivate (uint)
- **Returns**: `(response bool uint)`

#### `deactivate-child`
Deactivates a child profile (caregiver only)
- **Parameters**: `child-id`: ID of child to deactivate (uint)
- **Returns**: `(response bool uint)`

### Read-Only Functions

#### `get-caregiver`
Returns caregiver information
- **Parameters**: `caregiver`: Principal of caregiver
- **Returns**: Caregiver data or none

#### `get-child`
Returns child information
- **Parameters**: `child-id`: ID of child (uint)
- **Returns**: Child data or none

#### `get-sponsor`
Returns sponsor information
- **Parameters**: `sponsor`: Principal of sponsor
- **Returns**: Sponsor data or none

#### `get-sponsorship`
Returns sponsorship information
- **Parameters**: `sponsorship-id`: ID of sponsorship (uint)
- **Returns**: Sponsorship data or none

#### `get-contract-stats`
Returns overall contract statistics
- **Returns**: Total children, sponsorships, and contract balance

#### `is-child-sponsored`
Checks if a child has an active sponsorship
- **Parameters**: `child-id`: ID of child (uint)
- **Returns**: `bool`

## Usage Flow

1. **Caregiver Setup**:
   ```clarity
   (contract-call? .sponsorbit register-caregiver)
   ;; Admin verifies caregiver
   (contract-call? .sponsorbit verify-caregiver 'SP1CAREGIVER...)
   ```

2. **Child Registration**:
   ```clarity
   (contract-call? .sponsorbit register-child "John Doe" u8 "Kenya" u1000000)
   ```

3. **Sponsor Registration**:
   ```clarity
   (contract-call? .sponsorbit register-sponsor)
   ```

4. **Create Sponsorship**:
   ```clarity
   (contract-call? .sponsorbit create-sponsorship u1 u1000000)
   ```

5. **Make Monthly Payment**:
   ```clarity
   (contract-call? .sponsorbit make-payment u1)
   ```

## Error Codes

- `u100`: Owner only operation
- `u101`: Resource not found
- `u102`: Resource already exists
- `u103`: Insufficient funds
- `u104`: Caregiver not verified
- `u105`: Invalid amount
- `u106`: Child already sponsored
- `u107`: Unauthorized operation

## Testing

Run tests using Clarinet:

```bash
clarinet test
```

## Deployment

Deploy to testnet:

```bash
clarinet deploy --testnet
```

Deploy to mainnet:

```bash
clarinet deploy --mainnet
```

## Security Considerations

- Only contract owner can verify caregivers
- Caregivers must be verified before registering children
- Each child can only have one active sponsorship
- Sponsors can only manage their own sponsorships
- Caregivers can only manage their own children
- All payments go directly to caregiver wallets

## License

MIT License
