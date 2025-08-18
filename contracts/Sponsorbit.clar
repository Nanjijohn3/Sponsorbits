(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-insufficient-funds (err u103))
(define-constant err-not-verified (err u104))
(define-constant err-invalid-amount (err u105))
(define-constant err-sponsorship-exists (err u106))
(define-constant err-unauthorized (err u107))
(define-constant err-invalid-rating (err u108))
(define-constant err-already-rated (err u109))
(define-constant err-cannot-rate-self (err u110))
(define-constant err-no-interaction (err u111))
(define-constant err-insufficient-emergency-funds (err u112))
(define-constant err-invalid-emergency-amount (err u113))
(define-constant err-emergency-request-exists (err u114))
(define-constant err-emergency-not-approved (err u115))
(define-constant err-emergency-already-disbursed (err u116))
(define-constant err-emergency-expired (err u117))

(define-data-var next-child-id uint u1)
(define-data-var next-sponsorship-id uint u1)
(define-data-var contract-balance uint u0)
(define-data-var next-rating-id uint u1)
(define-data-var emergency-fund-balance uint u0)
(define-data-var next-emergency-request-id uint u1)

(define-map caregivers
  { caregiver: principal }
  {
    verified: bool,
    total-children: uint,
    total-received: uint,
    registered-at: uint
  }
)

(define-map children
  { child-id: uint }
  {
    caregiver: principal,
    name: (string-ascii 50),
    age: uint,
    location: (string-ascii 100),
    monthly-need: uint,
    active: bool,
    created-at: uint
  }
)

(define-map sponsorships
  { sponsorship-id: uint }
  {
    sponsor: principal,
    child-id: uint,
    monthly-amount: uint,
    total-donated: uint,
    active: bool,
    created-at: uint,
    last-payment: uint
  }
)

(define-map sponsors
  { sponsor: principal }
  {
    total-sponsored: uint,
    total-donated: uint,
    active-sponsorships: uint,
    registered-at: uint
  }
)

(define-map child-sponsorships
  { child-id: uint }
  { sponsorship-id: uint }
)

(define-map reputation-scores
  { user: principal }
  {
    total-ratings: uint,
    total-score: uint,
    average-rating: uint,
    last-updated: uint
  }
)

(define-map ratings
  { rating-id: uint }
  {
    rater: principal,
    rated-user: principal,
    rating: uint,
    comment: (string-ascii 200),
    rating-type: (string-ascii 20),
    sponsorship-id: (optional uint),
    created-at: uint
  }
)

(define-map user-ratings
  { rater: principal, rated-user: principal }
  { rating-id: uint }
)

(define-map reputation-rewards
  { user: principal }
  {
    bonus-percentage: uint,
    trust-level: uint,
    total-rewards-earned: uint,
    last-reward-claimed: uint
  }
)

(define-map emergency-fund-contributors
  { contributor: principal }
  {
    total-contributed: uint,
    contribution-count: uint,
    last-contribution: uint,
    active: bool
  }
)

(define-map emergency-requests
  { request-id: uint }
  {
    caregiver: principal,
    child-id: uint,
    amount-requested: uint,
    reason: (string-ascii 300),
    urgency-level: uint,
    approved: bool,
    disbursed: bool,
    requested-at: uint,
    approved-at: uint,
    disbursed-at: uint,
    expires-at: uint
  }
)

(define-map emergency-disbursements
  { request-id: uint }
  {
    amount-disbursed: uint,
    disbursed-to: principal,
    disbursed-by: principal,
    transaction-id: uint
  }
)

(define-public (register-caregiver)
  (let ((caregiver tx-sender))
    (if (is-some (map-get? caregivers { caregiver: caregiver }))
      err-already-exists
      (ok (map-set caregivers
        { caregiver: caregiver }
        {
          verified: false,
          total-children: u0,
          total-received: u0,
          registered-at: stacks-block-height
        }
      ))
    )
  )
)

(define-public (verify-caregiver (caregiver principal))
  (if (is-eq tx-sender contract-owner)
    (match (map-get? caregivers { caregiver: caregiver })
      caregiver-data
      (ok (map-set caregivers
        { caregiver: caregiver }
        (merge caregiver-data { verified: true })
      ))
      err-not-found
    )
    err-owner-only
  )
)

(define-public (register-child (name (string-ascii 50)) (age uint) (location (string-ascii 100)) (monthly-need uint))
  (let ((caregiver tx-sender)
        (child-id (var-get next-child-id)))
    (match (map-get? caregivers { caregiver: caregiver })
      caregiver-data
      (if (get verified caregiver-data)
        (begin
          (map-set children
            { child-id: child-id }
            {
              caregiver: caregiver,
              name: name,
              age: age,
              location: location,
              monthly-need: monthly-need,
              active: true,
              created-at: stacks-block-height
            }
          )
          (map-set caregivers
            { caregiver: caregiver }
            (merge caregiver-data { total-children: (+ (get total-children caregiver-data) u1) })
          )
          (var-set next-child-id (+ child-id u1))
          (ok child-id)
        )
        err-not-verified
      )
      err-not-found
    )
  )
)

(define-public (register-sponsor)
  (let ((sponsor tx-sender))
    (if (is-some (map-get? sponsors { sponsor: sponsor }))
      err-already-exists
      (ok (map-set sponsors
        { sponsor: sponsor }
        {
          total-sponsored: u0,
          total-donated: u0,
          active-sponsorships: u0,
          registered-at: stacks-block-height
        }
      ))
    )
  )
)

(define-public (create-sponsorship (child-id uint) (monthly-amount uint))
  (let ((sponsor tx-sender)
        (sponsorship-id (var-get next-sponsorship-id)))
    (if (> monthly-amount u0)
      (match (map-get? children { child-id: child-id })
        child-data
        (if (get active child-data)
          (if (is-none (map-get? child-sponsorships { child-id: child-id }))
            (match (map-get? sponsors { sponsor: sponsor })
              sponsor-data
              (begin
                (map-set sponsorships
                  { sponsorship-id: sponsorship-id }
                  {
                    sponsor: sponsor,
                    child-id: child-id,
                    monthly-amount: monthly-amount,
                    total-donated: u0,
                    active: true,
                    created-at: stacks-block-height,
                    last-payment: u0
                  }
                )
                (map-set child-sponsorships
                  { child-id: child-id }
                  { sponsorship-id: sponsorship-id }
                )
                (map-set sponsors
                  { sponsor: sponsor }
                  (merge sponsor-data { 
                    total-sponsored: (+ (get total-sponsored sponsor-data) u1),
                    active-sponsorships: (+ (get active-sponsorships sponsor-data) u1)
                  })
                )
                (var-set next-sponsorship-id (+ sponsorship-id u1))
                (ok sponsorship-id)
              )
              err-not-found
            )
            err-sponsorship-exists
          )
          err-not-found
        )
        err-not-found
      )
      err-invalid-amount
    )
  )
)

(define-public (make-payment (sponsorship-id uint))
  (match (map-get? sponsorships { sponsorship-id: sponsorship-id })
    sponsorship-data
    (if (is-eq tx-sender (get sponsor sponsorship-data))
      (if (get active sponsorship-data)
        (let ((amount (get monthly-amount sponsorship-data))
              (child-id (get child-id sponsorship-data)))
          (match (map-get? children { child-id: child-id })
            child-data
            (let ((caregiver (get caregiver child-data)))
              (match (stx-transfer? amount tx-sender caregiver)
                success
                (begin
                  (map-set sponsorships
                    { sponsorship-id: sponsorship-id }
                    (merge sponsorship-data {
                      total-donated: (+ (get total-donated sponsorship-data) amount),
                      last-payment: stacks-block-height
                    })
                  )
                  (match (map-get? sponsors { sponsor: tx-sender })
                    sponsor-data
                    (map-set sponsors
                      { sponsor: tx-sender }
                      (merge sponsor-data { total-donated: (+ (get total-donated sponsor-data) amount) })
                    )
                    true
                  )
                  (match (map-get? caregivers { caregiver: caregiver })
                    caregiver-data
                    (map-set caregivers
                      { caregiver: caregiver }
                      (merge caregiver-data { total-received: (+ (get total-received caregiver-data) amount) })
                    )
                    true
                  )
                  (ok true)
                )
                error
                (err error)
              )
            )
            err-not-found
          )
        )
        err-not-found
      )
      err-unauthorized
    )
    err-not-found
  )
)

(define-public (deactivate-sponsorship (sponsorship-id uint))
  (match (map-get? sponsorships { sponsorship-id: sponsorship-id })
    sponsorship-data
    (if (is-eq tx-sender (get sponsor sponsorship-data))
      (let ((child-id (get child-id sponsorship-data)))
        (map-set sponsorships
          { sponsorship-id: sponsorship-id }
          (merge sponsorship-data { active: false })
        )
        (map-delete child-sponsorships { child-id: child-id })
        (match (map-get? sponsors { sponsor: tx-sender })
          sponsor-data
          (map-set sponsors
            { sponsor: tx-sender }
            (merge sponsor-data { active-sponsorships: (- (get active-sponsorships sponsor-data) u1) })
          )
          true
        )
        (ok true)
      )
      err-unauthorized
    )
    err-not-found
  )
)

(define-public (deactivate-child (child-id uint))
  (match (map-get? children { child-id: child-id })
    child-data
    (if (is-eq tx-sender (get caregiver child-data))
      (begin
        (map-set children
          { child-id: child-id }
          (merge child-data { active: false })
        )
        (match (map-get? child-sponsorships { child-id: child-id })
          sponsorship-ref
          (let ((sponsorship-id (get sponsorship-id sponsorship-ref)))
            (match (map-get? sponsorships { sponsorship-id: sponsorship-id })
              sponsorship-data
              (map-set sponsorships
                { sponsorship-id: sponsorship-id }
                (merge sponsorship-data { active: false })
              )
              true
            )
            (map-delete child-sponsorships { child-id: child-id })
          )
          true
        )
        (ok true)
      )
      err-unauthorized
    )
    err-not-found
  )
)

(define-read-only (get-caregiver (caregiver principal))
  (map-get? caregivers { caregiver: caregiver })
)

(define-read-only (get-child (child-id uint))
  (map-get? children { child-id: child-id })
)

(define-read-only (get-sponsor (sponsor principal))
  (map-get? sponsors { sponsor: sponsor })
)

(define-read-only (get-sponsorship (sponsorship-id uint))
  (map-get? sponsorships { sponsorship-id: sponsorship-id })
)

(define-read-only (get-child-sponsorship (child-id uint))
  (map-get? child-sponsorships { child-id: child-id })
)

(define-read-only (get-contract-stats)
  {
    total-children: (- (var-get next-child-id) u1),
    total-sponsorships: (- (var-get next-sponsorship-id) u1),
    contract-balance: (var-get contract-balance)
  }
)

(define-read-only (is-child-sponsored (child-id uint))
  (is-some (map-get? child-sponsorships { child-id: child-id }))
)

(define-read-only (get-contract-owner)
  contract-owner
)

(define-public (rate-user (rated-user principal) (rating uint) (comment (string-ascii 200)) (rating-type (string-ascii 20)) (sponsorship-id (optional uint)))
  (let ((rater tx-sender)
        (rating-id (var-get next-rating-id)))
    (if (is-eq rater rated-user)
      err-cannot-rate-self
      (if (and (>= rating u1) (<= rating u5))
        (if (is-none (map-get? user-ratings { rater: rater, rated-user: rated-user }))
          (if (has-interaction rater rated-user sponsorship-id)
            (begin
              (map-set ratings
                { rating-id: rating-id }
                {
                  rater: rater,
                  rated-user: rated-user,
                  rating: rating,
                  comment: comment,
                  rating-type: rating-type,
                  sponsorship-id: sponsorship-id,
                  created-at: stacks-block-height
                }
              )
              (map-set user-ratings
                { rater: rater, rated-user: rated-user }
                { rating-id: rating-id }
              )
              (update-reputation-score rated-user rating)
              (update-trust-level rated-user)
              (var-set next-rating-id (+ rating-id u1))
              (ok rating-id)
            )
            err-no-interaction
          )
          err-already-rated
        )
        err-invalid-rating
      )
    )
  )
)

(define-private (has-interaction (rater principal) (rated-user principal) (sponsorship-id (optional uint)))
  (if (is-some sponsorship-id)
    (match (map-get? sponsorships { sponsorship-id: (unwrap-panic sponsorship-id) })
      sponsorship-data
      (or 
        (is-eq rater (get sponsor sponsorship-data))
        (match (map-get? children { child-id: (get child-id sponsorship-data) })
          child-data
          (is-eq rated-user (get caregiver child-data))
          false
        )
      )
      false
    )
    (or
      (has-sponsor-caregiver-interaction rater rated-user)
      (has-sponsor-caregiver-interaction rated-user rater)
    )
  )
)

(define-private (has-sponsor-caregiver-interaction (sponsor principal) (caregiver principal))
  (let ((sponsor-data (map-get? sponsors { sponsor: sponsor })))
    (and
      (is-some sponsor-data)
      (> (get total-donated (unwrap-panic sponsor-data)) u0)
      (is-some (map-get? caregivers { caregiver: caregiver }))
    )
  )
)

(define-private (update-reputation-score (user principal) (new-rating uint))
  (let ((current-score (default-to 
                         { total-ratings: u0, total-score: u0, average-rating: u0, last-updated: u0 }
                         (map-get? reputation-scores { user: user }))))
    (let ((new-total-ratings (+ (get total-ratings current-score) u1))
          (new-total-score (+ (get total-score current-score) new-rating)))
      (map-set reputation-scores
        { user: user }
        {
          total-ratings: new-total-ratings,
          total-score: new-total-score,
          average-rating: (/ new-total-score new-total-ratings),
          last-updated: stacks-block-height
        }
      )
    )
  )
)

(define-private (update-trust-level (user principal))
  (let ((reputation (default-to 
                      { total-ratings: u0, total-score: u0, average-rating: u0, last-updated: u0 }
                      (map-get? reputation-scores { user: user })))
        (current-rewards (default-to 
                           { bonus-percentage: u0, trust-level: u1, total-rewards-earned: u0, last-reward-claimed: u0 }
                           (map-get? reputation-rewards { user: user }))))
    (let ((new-trust-level (calculate-trust-level (get total-ratings reputation) (get average-rating reputation)))
          (new-bonus (calculate-bonus-percentage new-trust-level)))
      (map-set reputation-rewards
        { user: user }
        (merge current-rewards {
          bonus-percentage: new-bonus,
          trust-level: new-trust-level
        })
      )
    )
  )
)

(define-private (calculate-trust-level (total-ratings uint) (average-rating uint))
  (if (< total-ratings u3)
    u1
    (if (and (>= total-ratings u3) (>= average-rating u4))
      (if (and (>= total-ratings u10) (>= average-rating u4))
        (if (and (>= total-ratings u25) (is-eq average-rating u5))
          u5
          u4
        )
        u3
      )
      u2
    )
  )
)

(define-private (calculate-bonus-percentage (trust-level uint))
  (if (is-eq trust-level u1)
    u0
    (if (is-eq trust-level u2)
      u5
      (if (is-eq trust-level u3)
        u10
        (if (is-eq trust-level u4)
          u15
          u25
        )
      )
    )
  )
)

(define-public (claim-reputation-reward)
  (let ((user tx-sender)
        (rewards (map-get? reputation-rewards { user: user })))
    (match rewards
      reward-data
      (if (> (get trust-level reward-data) u1)
        (let ((reward-amount (calculate-reward-amount user))
              (current-balance (stx-get-balance tx-sender)))
          (if (> reward-amount u0)
            (begin
              (try! (stx-transfer? reward-amount contract-owner user))
              (map-set reputation-rewards
                { user: user }
                (merge reward-data {
                  total-rewards-earned: (+ (get total-rewards-earned reward-data) reward-amount),
                  last-reward-claimed: stacks-block-height
                })
              )
              (ok reward-amount)
            )
            (ok u0)
          )
        )
        err-not-verified
      )
      err-not-found
    )
  )
)

(define-private (calculate-reward-amount (user principal))
  (let ((rewards (default-to 
                   { bonus-percentage: u0, trust-level: u1, total-rewards-earned: u0, last-reward-claimed: u0 }
                   (map-get? reputation-rewards { user: user })))
        (last-claim (get last-reward-claimed rewards))
        (blocks-since-claim (- stacks-block-height last-claim)))
    (if (>= blocks-since-claim u144)
      (* (get trust-level rewards) u1000)
      u0
    )
  )
)

(define-read-only (get-reputation-score (user principal))
  (map-get? reputation-scores { user: user })
)

(define-read-only (get-user-rating (rater principal) (rated-user principal))
  (match (map-get? user-ratings { rater: rater, rated-user: rated-user })
    rating-ref
    (map-get? ratings { rating-id: (get rating-id rating-ref) })
    none
  )
)

(define-read-only (get-rating (rating-id uint))
  (map-get? ratings { rating-id: rating-id })
)

(define-read-only (get-reputation-rewards (user principal))
  (map-get? reputation-rewards { user: user })
)

(define-read-only (get-trust-level (user principal))
  (match (map-get? reputation-rewards { user: user })
    reward-data
    (some (get trust-level reward-data))
    (some u1)
  )
)

(define-read-only (calculate-reputation-bonus (base-amount uint) (user principal))
  (let ((rewards (default-to 
                   { bonus-percentage: u0, trust-level: u1, total-rewards-earned: u0, last-reward-claimed: u0 }
                   (map-get? reputation-rewards { user: user }))))
    (+ base-amount (/ (* base-amount (get bonus-percentage rewards)) u100))
  )
)

(define-public (contribute-to-emergency-fund (amount uint))
  (let ((contributor tx-sender))
    (if (> amount u0)
      (match (stx-transfer? amount contributor (as-contract tx-sender))
        success
        (begin
          (let ((current-contributor (default-to 
                                      { total-contributed: u0, contribution-count: u0, last-contribution: u0, active: true }
                                      (map-get? emergency-fund-contributors { contributor: contributor }))))
            (map-set emergency-fund-contributors
              { contributor: contributor }
              {
                total-contributed: (+ (get total-contributed current-contributor) amount),
                contribution-count: (+ (get contribution-count current-contributor) u1),
                last-contribution: stacks-block-height,
                active: true
              }
            )
            (var-set emergency-fund-balance (+ (var-get emergency-fund-balance) amount))
            (ok amount)
          )
        )
        error
        (err error)
      )
      err-invalid-emergency-amount
    )
  )
)

(define-public (request-emergency-funds (child-id uint) (amount uint) (reason (string-ascii 300)) (urgency-level uint))
  (let ((caregiver tx-sender)
        (request-id (var-get next-emergency-request-id)))
    (if (and (> amount u0) (<= urgency-level u5) (>= urgency-level u1))
      (match (map-get? children { child-id: child-id })
        child-data
        (if (and (is-eq caregiver (get caregiver child-data)) (get active child-data))
          (match (map-get? caregivers { caregiver: caregiver })
            caregiver-data
            (if (get verified caregiver-data)
              (if (is-none (get-active-emergency-request caregiver child-id))
                (let ((expires-at (+ stacks-block-height (calculate-expiry-blocks urgency-level))))
                  (map-set emergency-requests
                    { request-id: request-id }
                    {
                      caregiver: caregiver,
                      child-id: child-id,
                      amount-requested: amount,
                      reason: reason,
                      urgency-level: urgency-level,
                      approved: false,
                      disbursed: false,
                      requested-at: stacks-block-height,
                      approved-at: u0,
                      disbursed-at: u0,
                      expires-at: expires-at
                    }
                  )
                  (map-set caregiver-active-requests
                    { caregiver: caregiver, child-id: child-id }
                    { request-id: request-id, expires-at: expires-at }
                  )
                  (var-set next-emergency-request-id (+ request-id u1))
                  (ok request-id)
                )
                err-emergency-request-exists
              )
              err-not-verified
            )
            err-not-found
          )
          err-unauthorized
        )
        err-not-found
      )
      err-invalid-emergency-amount
    )
  )
)

(define-public (approve-emergency-request (request-id uint))
  (if (is-eq tx-sender contract-owner)
    (match (map-get? emergency-requests { request-id: request-id })
      request-data
      (if (not (get approved request-data))
        (if (< stacks-block-height (get expires-at request-data))
          (let ((amount (get amount-requested request-data)))
            (if (<= amount (var-get emergency-fund-balance))
              (begin
                (map-set emergency-requests
                  { request-id: request-id }
                  (merge request-data {
                    approved: true,
                    approved-at: stacks-block-height
                  })
                )
                (ok true)
              )
              err-insufficient-emergency-funds
            )
          )
          err-emergency-expired
        )
        err-emergency-not-approved
      )
      err-not-found
    )
    err-owner-only
  )
)

(define-public (disburse-emergency-funds (request-id uint))
  (if (is-eq tx-sender contract-owner)
    (match (map-get? emergency-requests { request-id: request-id })
      request-data
      (if (and (get approved request-data) (not (get disbursed request-data)))
        (if (< stacks-block-height (get expires-at request-data))
          (let ((amount (get amount-requested request-data))
                (caregiver (get caregiver request-data)))
            (if (<= amount (var-get emergency-fund-balance))
              (match (as-contract (stx-transfer? amount tx-sender caregiver))
                success
                (begin
                  (map-set emergency-requests
                    { request-id: request-id }
                    (merge request-data {
                      disbursed: true,
                      disbursed-at: stacks-block-height
                    })
                  )
                  (map-set emergency-disbursements
                    { request-id: request-id }
                    {
                      amount-disbursed: amount,
                      disbursed-to: caregiver,
                      disbursed-by: tx-sender,
                      transaction-id: stacks-block-height
                    }
                  )
                  (map-delete caregiver-active-requests { caregiver: caregiver, child-id: (get child-id request-data) })
                  (var-set emergency-fund-balance (- (var-get emergency-fund-balance) amount))
                  (match (map-get? caregivers { caregiver: caregiver })
                    caregiver-data
                    (map-set caregivers
                      { caregiver: caregiver }
                      (merge caregiver-data { total-received: (+ (get total-received caregiver-data) amount) })
                    )
                    true
                  )
                  (ok amount)
                )
                error
                (err error)
              )
              err-insufficient-emergency-funds
            )
          )
          err-emergency-expired
        )
        err-emergency-already-disbursed
      )
      err-not-found
    )
    err-owner-only
  )
)

(define-map caregiver-active-requests
  { caregiver: principal, child-id: uint }
  { request-id: uint, expires-at: uint }
)

(define-private (get-active-emergency-request (caregiver principal) (child-id uint))
  (match (map-get? caregiver-active-requests { caregiver: caregiver, child-id: child-id })
    active-request
    (if (< stacks-block-height (get expires-at active-request))
      (some (get request-id active-request))
      (begin
        (map-delete caregiver-active-requests { caregiver: caregiver, child-id: child-id })
        none
      )
    )
    none
  )
)

(define-private (calculate-expiry-blocks (urgency-level uint))
  (if (is-eq urgency-level u5)
    u144
    (if (is-eq urgency-level u4)
      u288
      (if (is-eq urgency-level u3)
        u432
        (if (is-eq urgency-level u2)
          u720
          u1440
        )
      )
    )
  )
)

(define-read-only (get-emergency-fund-balance)
  (var-get emergency-fund-balance)
)

(define-read-only (get-emergency-fund-contributor (contributor principal))
  (map-get? emergency-fund-contributors { contributor: contributor })
)

(define-read-only (get-emergency-request (request-id uint))
  (map-get? emergency-requests { request-id: request-id })
)

(define-read-only (get-emergency-disbursement (request-id uint))
  (map-get? emergency-disbursements { request-id: request-id })
)

(define-read-only (get-emergency-fund-stats)
  {
    total-balance: (var-get emergency-fund-balance),
    total-requests: (- (var-get next-emergency-request-id) u1),
    next-request-id: (var-get next-emergency-request-id)
  }
)



