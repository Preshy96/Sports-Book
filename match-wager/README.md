# Sports Betting Smart Contract

## About
This smart contract implements a decentralized sports betting platform on the Stacks blockchain. It allows users to create betting events, place bets, and manage payouts for various types of betting scenarios. The contract supports multiple betting types including winner-take-all, proportional, and fixed-odds betting.

## Features
- Create and manage betting events
- Support for multiple betting types
- Secure stake management
- Automated payout calculations
- Built-in refund mechanism
- Configurable betting windows
- Support for multiple winners

## Betting Types
1. **Winner-Take-All**
   - Total pool is divided equally among winning bets
   - No odds configuration required

2. **Proportional**
   - Payouts are calculated based on stake ratio
   - Fair distribution based on contribution

3. **Fixed-Odds**
   - Traditional betting with predetermined odds
   - Requires odds configuration during event creation

## Core Functions

### Event Management
```clarity
(create-betting-event (event-description (string-ascii 256)) 
                     (available-options (list 10 (string-ascii 64))) 
                     (closing-block-height uint) 
                     (betting-type (string-ascii 20)) 
                     (betting-odds (optional (list 10 uint))))
```
Creates a new betting event with specified parameters.

```clarity
(close-betting-event (event-id uint))
```
Closes betting for an event after the specified block height.

```clarity
(cancel-betting-event (event-id uint))
```
Cancels an event and processes refunds to participants.

### Participant Functions
```clarity
(place-bet (event-id uint) (selected-option uint) (wager-amount uint))
```
Places a bet on a specific option in an event.

```clarity
(claim-payout (event-id uint))
```
Claims winnings after event settlement.

### Administrative Functions
```clarity
(settle-betting-event (event-id uint) (winning-option-ids (list 5 uint)))
```
Settles an event by declaring winning options.

## Error Codes
- `ERR-UNAUTHORIZED (u100)`: Unauthorized access attempt
- `ERR-EVENT-ALREADY-EXISTS (u101)`: Event ID already exists
- `ERR-EVENT-DOES-NOT-EXIST (u102)`: Referenced event doesn't exist
- `ERR-EVENT-CLOSED (u103)`: Event is closed for betting
- `ERR-INSUFFICIENT-BALANCE (u104)`: Insufficient funds for bet
- `ERR-EVENT-ALREADY-SETTLED (u105)`: Event already settled
- `ERR-EVENT-NOT-CLOSABLE (u106)`: Event cannot be closed yet
- `ERR-EVENT-NOT-CANCELABLE (u107)`: Event cannot be canceled
- `ERR-INVALID-BETTING-OPTIONS-COUNT (u108)`: Invalid number of options
- `ERR-INVALID-CLOSING-BLOCK-HEIGHT (u109)`: Invalid closing height
- `ERR-INVALID-BETTING-TYPE (u110)`: Invalid betting type
- `ERR-MISSING-BETTING-ODDS (u111)`: Missing required odds
- `ERR-INVALID-BETTING-OPTION (u112)`: Invalid betting option
- `ERR-EVENT-EXPIRED (u113)`: Event has expired
- `ERR-NO-WINNING-BETTING-OPTIONS (u114)`: No winning options declared
- `ERR-EXCESSIVE-WINNERS (u115)`: Too many winning options
- `ERR-INVALID-WINNING-OPTION (u116)`: Invalid winning option
- `ERR-NOT-WINNING-OPTION (u117)`: Option is not a winner
- `ERR-REFUND-TRANSACTION-FAILED (u118)`: Refund transaction failed
- `ERR-REFUND-IN-PROGRESS (u119)`: Refund already in progress
- `ERR-INVALID-EVENT-DESCRIPTION (u120)`: Invalid event description
- `ERR-INVALID-STAKE-AMOUNT (u121)`: Invalid stake amount

## Usage Example

1. Create a betting event:
```clarity
(create-betting-event "World Cup Final 2024" 
                     (list "Team A" "Team B") 
                     u100000 
                     "fixed-odds" 
                     (some (list u150 u250)))
```

2. Place a bet:
```clarity
(place-bet u1 u1 u1000)
```

3. Close betting:
```clarity
(close-betting-event u1)
```

4. Settle event:
```clarity
(settle-betting-event u1 (list u1))
```

5. Claim winnings:
```clarity
(claim-payout u1)
```

## Security Considerations

1. **Block Height Validation**
   - Events can only be closed after reaching specified block height
   - Prevents premature closing of events

2. **Access Control**
   - Only event creator can cancel events
   - Only contract administrator can settle events
   - Prevents unauthorized modifications

3. **Fund Safety**
   - Automated refund mechanism for cancelled events
   - Protected payout calculations
   - Safe stake management

4. **Input Validation**
   - Comprehensive validation for all inputs
   - Protection against invalid options and amounts

## Limitations

1. Maximum of 10 betting options per event
2. Maximum of 5 winning options per event
3. Event descriptions limited to 256 ASCII characters
4. Option descriptions limited to 64 ASCII characters
5. Fixed list of betting types (winner-take-all, proportional, fixed-odds)

## Best Practices

1. **Event Creation**
   - Set appropriate closing block heights
   - Provide clear, detailed event descriptions
   - Configure proper odds for fixed-odds betting

2. **Betting**
   - Verify event status before placing bets
   - Check closing times and odds
   - Understand the betting type and payout mechanism

3. **Settlement**
   - Wait for event completion
   - Verify results before settlement
   - Ensure proper winner selection