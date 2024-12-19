;; Sports Betting Contract

;; Error Constants
(define-constant contract-administrator tx-sender)
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-EVENT-ALREADY-EXISTS (err u101))
(define-constant ERR-EVENT-DOES-NOT-EXIST (err u102))
(define-constant ERR-EVENT-CLOSED (err u103))
(define-constant ERR-INSUFFICIENT-BALANCE (err u104))
(define-constant ERR-EVENT-ALREADY-SETTLED (err u105))
(define-constant ERR-EVENT-NOT-CLOSABLE (err u106))
(define-constant ERR-EVENT-NOT-CANCELABLE (err u107))
(define-constant ERR-INVALID-BETTING-OPTIONS-COUNT (err u108))
(define-constant ERR-INVALID-CLOSING-BLOCK-HEIGHT (err u109))
(define-constant ERR-INVALID-BETTING-TYPE (err u110))
(define-constant ERR-MISSING-BETTING-ODDS (err u111))
(define-constant ERR-INVALID-BETTING-OPTION (err u112))
(define-constant ERR-EVENT-EXPIRED (err u113))
(define-constant ERR-NO-WINNING-BETTING-OPTIONS (err u114))
(define-constant ERR-EXCESSIVE-WINNERS (err u115))
(define-constant ERR-INVALID-WINNING-OPTION (err u116))
(define-constant ERR-NOT-WINNING-OPTION (err u117))
(define-constant ERR-REFUND-TRANSACTION-FAILED (err u118))
(define-constant ERR-REFUND-IN-PROGRESS (err u119))
(define-constant ERR-INVALID-EVENT-DESCRIPTION (err u120))
(define-constant ERR-INVALID-STAKE-AMOUNT (err u121))

;; Data variables
(define-data-var next-event-id uint u0)

;; Betting types
(define-data-var available-betting-types (list 10 (string-ascii 20)) (list "winner-take-all" "proportional" "fixed-odds"))

;; Define betting event structure
(define-map betting-events
  { event-id: uint }
  {
    event-organizer: principal,
    event-description: (string-ascii 256),
    available-options: (list 10 (string-ascii 64)),
    total-pool-amount: uint,
    accepting-bets: bool,
    winning-option-ids: (list 5 uint),
    closing-block-height: uint,
    betting-type: (string-ascii 20),
    betting-odds: (optional (list 10 uint))
  }
)

;; Define participant stakes structure
(define-map participant-stakes
  { event-id: uint, participant: principal }
  { selected-option: uint, wagered-amount: uint }
)

;; Read-only functions

(define-read-only (get-betting-event (event-id uint))
  (map-get? betting-events { event-id: event-id })
)

(define-read-only (get-participant-stake (event-id uint) (participant principal))
  (map-get? participant-stakes { event-id: event-id, participant: participant })
)

(define-read-only (get-current-block-height)
  block-height
)

;; Private functions

(define-private (calculate-winning-payout (betting-event { event-organizer: principal, event-description: (string-ascii 256), available-options: (list 10 (string-ascii 64)), total-pool-amount: uint, accepting-bets: bool, winning-option-ids: (list 5 uint), closing-block-height: uint, betting-type: (string-ascii 20), betting-odds: (optional (list 10 uint)) }) (participant-stake { selected-option: uint, wagered-amount: uint }) (winning-options (list 5 uint)))
  (let
    (
      (event-betting-type (get betting-type betting-event))
      (total-event-pool (get total-pool-amount betting-event))
      (participant-wager (get wagered-amount participant-stake))
    )
    (if (is-eq event-betting-type "winner-take-all")
      ;; For winner-take-all, divide total pot by number of winning options
      (/ total-event-pool (len winning-options))
      (if (is-eq event-betting-type "proportional")
        ;; For proportional, payout based on stake ratio
        (/ (* participant-wager total-event-pool) total-event-pool)
        ;; Fixed-odds payout
        (let
          (
            (odds-list (unwrap! (get betting-odds betting-event) u0))
            (selected-odds (unwrap! (element-at odds-list (- (get selected-option participant-stake) u1)) u0))
          )
          (+ participant-wager (* participant-wager (/ selected-odds u100)))
        )
      )
    )
  )
)

(define-private (get-stake-amount-for-option (option-id uint) (event-id uint))
  (let
    (
      (participant-stake (get-participant-stake event-id tx-sender))
    )
    (if (is-some participant-stake)
      (let
        ((stake-details (unwrap! participant-stake u0)))
        (if (is-eq (get selected-option stake-details) option-id)
          (get wagered-amount stake-details)
          u0
        )
      )
      u0
    )
  )
)

(define-private (get-total-staked-for-option (option-id uint))
  (get-stake-amount-for-option option-id (var-get next-event-id))
)

(define-private (process-stake-refunds (event-id uint))
  (let
    ((participant-stake (get-participant-stake event-id tx-sender)))
    (match participant-stake
      stake-details (match (as-contract (stx-transfer? (get wagered-amount stake-details) tx-sender tx-sender))
        success (begin
          (map-delete participant-stakes { event-id: event-id, participant: tx-sender })
          (ok true)
        )
        error ERR-REFUND-TRANSACTION-FAILED
      )
      ERR-REFUND-IN-PROGRESS
    )
  )
)

(define-private (validate-winning-options (options (list 5 uint)) (max-valid-option uint))
  (let
    (
      (first-option (element-at options u0))
      (second-option (element-at options u1))
      (third-option (element-at options u2))
      (fourth-option (element-at options u3))
      (fifth-option (element-at options u4))
    )
    (and
      ;; Check if first option exists and is valid
      (match first-option
        value (and (> value u0) (<= value max-valid-option))
        true)
      ;; For remaining options, they're either valid or none
      (match second-option
        value (and (> value u0) (<= value max-valid-option))
        true)
      (match third-option
        value (and (> value u0) (<= value max-valid-option))
        true)
      (match fourth-option
        value (and (> value u0) (<= value max-valid-option))
        true)
      (match fifth-option
        value (and (> value u0) (<= value max-valid-option))
        true)
    )
  )
)

;; Public functions

(define-public (create-betting-event (event-description (string-ascii 256)) (available-options (list 10 (string-ascii 64))) (closing-block-height uint) (betting-type (string-ascii 20)) (betting-odds (optional (list 10 uint))))
  (let
    (
      (new-event-id (var-get next-event-id))
    )
    (asserts! (> (len event-description) u0) ERR-INVALID-EVENT-DESCRIPTION)
    (asserts! (> (len available-options) u1) ERR-INVALID-BETTING-OPTIONS-COUNT)
    (asserts! (> closing-block-height block-height) ERR-INVALID-CLOSING-BLOCK-HEIGHT)
    (asserts! (is-some (index-of (var-get available-betting-types) betting-type)) ERR-INVALID-BETTING-TYPE)
    (asserts! (or (is-eq betting-type "winner-take-all") (is-eq betting-type "proportional") (is-some betting-odds)) ERR-MISSING-BETTING-ODDS)
    (map-set betting-events
      { event-id: new-event-id }
      {
        event-organizer: tx-sender,
        event-description: event-description,
        available-options: available-options,
        total-pool-amount: u0,
        accepting-bets: true,
        winning-option-ids: (list),
        closing-block-height: closing-block-height,
        betting-type: betting-type,
        betting-odds: betting-odds
      }
    )
    (var-set next-event-id (+ new-event-id u1))
    (ok new-event-id)
  )
)

(define-public (place-bet (event-id uint) (selected-option uint) (wager-amount uint))
  (let
    (
      (betting-event (unwrap! (get-betting-event event-id) ERR-EVENT-DOES-NOT-EXIST))
      (existing-stake (default-to { selected-option: u0, wagered-amount: u0 } (get-participant-stake event-id tx-sender)))
    )
    (asserts! (> wager-amount u0) ERR-INVALID-STAKE-AMOUNT)
    (asserts! (get accepting-bets betting-event) ERR-EVENT-CLOSED)
    (asserts! (>= (len (get available-options betting-event)) selected-option) ERR-INVALID-BETTING-OPTION)
    (asserts! (< block-height (get closing-block-height betting-event)) ERR-EVENT-EXPIRED)
    (try! (stx-transfer? wager-amount tx-sender (as-contract tx-sender)))
    (map-set participant-stakes
      { event-id: event-id, participant: tx-sender }
      {
        selected-option: selected-option,
        wagered-amount: (+ wager-amount (get wagered-amount existing-stake))
      }
    )
    (map-set betting-events
      { event-id: event-id }
      (merge betting-event { total-pool-amount: (+ (get total-pool-amount betting-event) wager-amount) })
    )
    (ok true)
  )
)

(define-public (close-betting-event (event-id uint))
  (let
    (
      (betting-event (unwrap! (get-betting-event event-id) ERR-EVENT-DOES-NOT-EXIST))
    )
    (asserts! (or (is-eq (get event-organizer betting-event) tx-sender) (is-eq contract-administrator tx-sender)) ERR-UNAUTHORIZED)
    (asserts! (get accepting-bets betting-event) ERR-EVENT-CLOSED)
    (asserts! (>= block-height (get closing-block-height betting-event)) ERR-EVENT-NOT-CLOSABLE)
    (map-set betting-events
      { event-id: event-id }
      (merge betting-event { accepting-bets: false })
    )
    (ok true)
  )
)

(define-public (cancel-betting-event (event-id uint))
  (let
    (
      (betting-event (unwrap! (get-betting-event event-id) ERR-EVENT-DOES-NOT-EXIST))
    )
    (asserts! (is-eq (get event-organizer betting-event) tx-sender) ERR-UNAUTHORIZED)
    (asserts! (get accepting-bets betting-event) ERR-EVENT-CLOSED)
    (asserts! (< block-height (get closing-block-height betting-event)) ERR-EVENT-NOT-CANCELABLE)
    
    ;; First set the event as closed
    (map-set betting-events
      { event-id: event-id }
      (merge betting-event { accepting-bets: false })
    )
    
    ;; Then process refunds
    (process-stake-refunds event-id)
  )
)

(define-public (claim-payout (event-id uint))
  (let
    (
      (betting-event (unwrap! (get-betting-event event-id) ERR-EVENT-DOES-NOT-EXIST))
      (participant-stake (unwrap! (get-participant-stake event-id tx-sender) ERR-EVENT-DOES-NOT-EXIST))
      (winning-option-ids (get winning-option-ids betting-event))
    )
    (asserts! (is-some (index-of winning-option-ids (get selected-option participant-stake))) ERR-NOT-WINNING-OPTION)
    (let
      (
        (winning-payout (calculate-winning-payout betting-event participant-stake winning-option-ids))
      )
      (try! (as-contract (stx-transfer? winning-payout tx-sender tx-sender)))
      (map-delete participant-stakes { event-id: event-id, participant: tx-sender })
      (ok winning-payout)
    )
  )
)

(define-public (settle-betting-event (event-id uint) (winning-option-ids (list 5 uint)))
  (let
    (
      (betting-event (unwrap! (get-betting-event event-id) ERR-EVENT-DOES-NOT-EXIST))
    )
    (asserts! (is-eq contract-administrator tx-sender) ERR-UNAUTHORIZED)
    (asserts! (not (get accepting-bets betting-event)) ERR-EVENT-CLOSED)
    (asserts! (is-eq (len (get winning-option-ids betting-event)) u0) ERR-EVENT-ALREADY-SETTLED)
    (asserts! (> (len winning-option-ids) u0) ERR-NO-WINNING-BETTING-OPTIONS)
    (asserts! (<= (len winning-option-ids) u5) ERR-EXCESSIVE-WINNERS)
    
    ;; Validate each winning option
    (asserts! (validate-winning-options winning-option-ids (len (get available-options betting-event))) ERR-INVALID-WINNING-OPTION)
    
    (map-set betting-events
      { event-id: event-id }
      (merge betting-event { winning-option-ids: winning-option-ids })
    )
    (ok true)
  )
)

;; Contract initialization
(begin
  (var-set next-event-id u0)
)

;; Export the Component function
(define-public (Component)
  (ok true))