;; SponsorshipMilestones - Track child development milestones and sponsor engagement
;; Enables milestone-based progress tracking with optional sponsor rewards

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u200))
(define-constant err-milestone-not-found (err u201))
(define-constant err-invalid-parameters (err u202))
(define-constant err-milestone-completed (err u203))
(define-constant err-insufficient-funds (err u204))
(define-constant err-child-not-found (err u205))
(define-constant err-sponsorship-not-found (err u206))

;; Data variables
(define-data-var next-milestone-id uint u1)
(define-data-var milestone-reward-pool uint u0)

;; Milestone categories
(define-map milestone-categories
    (string-ascii 20)
    {
        category-name: (string-ascii 20),
        default-reward: uint,
        is-active: bool
    }
)

;; Child milestones
(define-map child-milestones
    uint
    {
        child-id: uint,
        caregiver: principal,
        title: (string-ascii 60),
        description: (string-ascii 200),
        category: (string-ascii 20),
        target-date: uint,
        reward-amount: uint,
        completed: bool,
        completed-date: (optional uint),
        verification-notes: (optional (string-ascii 150)),
        created-at: uint
    }
)

;; Milestone progress updates
(define-map milestone-progress
    {milestone-id: uint, update-id: uint}
    {
        progress-percentage: uint,
        update-description: (string-ascii 150),
        evidence-notes: (string-ascii 100),
        updated-by: principal,
        updated-at: uint
    }
)

;; Milestone completion rewards
(define-map milestone-rewards
    uint
    {
        milestone-id: uint,
        reward-amount: uint,
        paid-to: principal,
        paid-by: principal,
        paid-at: uint
    }
)

;; Track update counts per milestone
(define-map milestone-update-counts
    uint
    uint
)

;; Public functions

;; Initialize milestone categories (admin only)
(define-public (init-milestone-categories)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (map-set milestone-categories "education"
            {category-name: "education", default-reward: u500000, is-active: true})
        (map-set milestone-categories "health"
            {category-name: "health", default-reward: u300000, is-active: true})
        (map-set milestone-categories "personal"
            {category-name: "personal", default-reward: u200000, is-active: true})
        (map-set milestone-categories "social"
            {category-name: "social", default-reward: u250000, is-active: true})
        (ok true)
    )
)

;; Create milestone for child
(define-public (create-milestone
    (child-id uint)
    (title (string-ascii 60))
    (description (string-ascii 200))
    (category (string-ascii 20))
    (target-date uint)
    (custom-reward (optional uint)))
    (let
        (
            (milestone-id (var-get next-milestone-id))
            (caregiver tx-sender)
            (category-data (unwrap! (map-get? milestone-categories category) err-invalid-parameters))
            (reward-amount (default-to (get default-reward category-data) custom-reward))
        )
        (asserts! (get is-active category-data) err-invalid-parameters)
        (asserts! (> target-date stacks-block-height) err-invalid-parameters)
        (asserts! (> reward-amount u0) err-invalid-parameters)
        
        (map-set child-milestones milestone-id
            {
                child-id: child-id,
                caregiver: caregiver,
                title: title,
                description: description,
                category: category,
                target-date: target-date,
                reward-amount: reward-amount,
                completed: false,
                completed-date: none,
                verification-notes: none,
                created-at: stacks-block-height
            }
        )
        
        (map-set milestone-update-counts milestone-id u0)
        (var-set next-milestone-id (+ milestone-id u1))
        (ok milestone-id)
    )
)

;; Add progress update to milestone
(define-public (update-milestone-progress
    (milestone-id uint)
    (progress-percentage uint)
    (update-description (string-ascii 150))
    (evidence-notes (string-ascii 100)))
    (let
        (
            (milestone (unwrap! (map-get? child-milestones milestone-id) err-milestone-not-found))
            (update-count (default-to u0 (map-get? milestone-update-counts milestone-id)))
            (update-id (+ update-count u1))
        )
        (asserts! (is-eq tx-sender (get caregiver milestone)) err-not-authorized)
        (asserts! (not (get completed milestone)) err-milestone-completed)
        (asserts! (<= progress-percentage u100) err-invalid-parameters)
        
        (map-set milestone-progress 
            {milestone-id: milestone-id, update-id: update-id}
            {
                progress-percentage: progress-percentage,
                update-description: update-description,
                evidence-notes: evidence-notes,
                updated-by: tx-sender,
                updated-at: stacks-block-height
            }
        )
        
        (map-set milestone-update-counts milestone-id update-id)
        (ok update-id)
    )
)

;; Complete milestone and trigger reward
(define-public (complete-milestone
    (milestone-id uint)
    (verification-notes (string-ascii 150)))
    (let
        (
            (milestone (unwrap! (map-get? child-milestones milestone-id) err-milestone-not-found))
        )
        (asserts! (is-eq tx-sender (get caregiver milestone)) err-not-authorized)
        (asserts! (not (get completed milestone)) err-milestone-completed)
        
        (map-set child-milestones milestone-id
            (merge milestone {
                completed: true,
                completed-date: (some stacks-block-height),
                verification-notes: (some verification-notes)
            })
        )
        (ok true)
    )
)

;; Sponsor provides bonus reward for milestone completion
(define-public (provide-milestone-reward
    (milestone-id uint)
    (bonus-amount uint))
    (let
        (
            (milestone (unwrap! (map-get? child-milestones milestone-id) err-milestone-not-found))
            (caregiver (get caregiver milestone))
        )
        (asserts! (get completed milestone) err-invalid-parameters)
        (asserts! (> bonus-amount u0) err-invalid-parameters)
        (asserts! (>= (stx-get-balance tx-sender) bonus-amount) err-insufficient-funds)
        
        (try! (stx-transfer? bonus-amount tx-sender caregiver))
        
        (map-set milestone-rewards milestone-id
            {
                milestone-id: milestone-id,
                reward-amount: bonus-amount,
                paid-to: caregiver,
                paid-by: tx-sender,
                paid-at: stacks-block-height
            }
        )
        (ok true)
    )
)

;; Fund milestone reward pool (for future automatic rewards)
(define-public (fund-milestone-pool (amount uint))
    (begin
        (asserts! (> amount u0) err-invalid-parameters)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (var-set milestone-reward-pool (+ (var-get milestone-reward-pool) amount))
        (ok true)
    )
)

;; Read-only functions

;; Get milestone details
(define-read-only (get-milestone (milestone-id uint))
    (map-get? child-milestones milestone-id)
)

;; Get milestone progress update
(define-read-only (get-milestone-progress (milestone-id uint) (update-id uint))
    (map-get? milestone-progress {milestone-id: milestone-id, update-id: update-id})
)

;; Get milestone category info
(define-read-only (get-milestone-category (category (string-ascii 20)))
    (map-get? milestone-categories category)
)

;; Get milestone reward info
(define-read-only (get-milestone-reward (milestone-id uint))
    (map-get? milestone-rewards milestone-id)
)

;; Get total progress updates for milestone
(define-read-only (get-milestone-update-count (milestone-id uint))
    (default-to u0 (map-get? milestone-update-counts milestone-id))
)

;; Get reward pool balance
(define-read-only (get-milestone-reward-pool)
    (var-get milestone-reward-pool)
)

;; Check if milestone is overdue
(define-read-only (is-milestone-overdue (milestone-id uint))
    (match (map-get? child-milestones milestone-id)
        milestone-data
        (and 
            (not (get completed milestone-data))
            (> stacks-block-height (get target-date milestone-data))
        )
        false
    )
)

;; Get milestone completion rate for caregiver
(define-read-only (get-caregiver-milestone-stats (caregiver principal))
    (ok {
        total-milestones: u0, ;; Would need iteration to calculate
        completed-milestones: u0, ;; Would need iteration to calculate  
        completion-rate: u0 ;; Would need iteration to calculate
    })
)

;; Administrative functions

;; Add new milestone category (admin only)
(define-public (add-milestone-category 
    (category (string-ascii 20))
    (default-reward uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (asserts! (> default-reward u0) err-invalid-parameters)
        (map-set milestone-categories category
            {
                category-name: category,
                default-reward: default-reward,
                is-active: true
            }
        )
        (ok true)
    )
)

;; Update category reward amount (admin only)
(define-public (update-category-reward 
    (category (string-ascii 20))
    (new-reward uint))
    (let
        (
            (category-data (unwrap! (map-get? milestone-categories category) err-invalid-parameters))
        )
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (asserts! (> new-reward u0) err-invalid-parameters)
        (map-set milestone-categories category
            (merge category-data {default-reward: new-reward})
        )
        (ok true)
    )
)
