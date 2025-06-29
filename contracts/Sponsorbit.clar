(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-insufficient-funds (err u103))
(define-constant err-not-verified (err u104))
(define-constant err-invalid-amount (err u105))
(define-constant err-sponsorship-exists (err u106))
(define-constant err-unauthorized (err u107))

(define-data-var next-child-id uint u1)
(define-data-var next-sponsorship-id uint u1)
(define-data-var contract-balance uint u0)

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
