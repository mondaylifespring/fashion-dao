;; FashionDAO - Decentralized Autonomous Organization for fashion designers
(define-fungible-token fashion-dao-token)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u403))
(define-constant err-not-enough-tokens (err u100))
(define-constant err-proposal-not-found (err u101))
(define-constant err-already-voted (err u102))
(define-constant err-proposal-ended (err u103))
(define-constant err-proposal-not-ended (err u104))
(define-constant err-invalid-title (err u105))
(define-constant err-invalid-description (err u106))
(define-constant err-invalid-link (err u107))
(define-constant err-invalid-amount (err u108))

;; Storage
(define-map proposals uint {
  proposer: principal,
  title: (string-utf8 64),
  description: (string-utf8 256),
  link: (string-utf8 128),
  votes-for: uint,
  votes-against: uint,
  status: (string-utf8 16),
  execution-deadline: uint
})

(define-map votes {proposal-id: uint, voter: principal} bool)
(define-map member-tokens principal uint)
(define-data-var proposal-id-nonce uint u0)
(define-data-var min-proposal-threshold uint u100000000) ;; 100 tokens
(define-data-var voting-period uint u144) ;; ~1 day in blocks

;; Initialize tokens for founder
(define-public (initialize-tokens (amount uint))
  (begin
    ;; Validate inputs
    (asserts! (> amount u0) err-invalid-amount)
    
    ;; Check authorization
    (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
    
    ;; Mint tokens
    (try! (ft-mint? fashion-dao-token amount tx-sender))
    
    ;; Update member tokens
    (ok (map-set member-tokens tx-sender amount))
  )
)

;; Create a new proposal
(define-public (create-proposal (title (string-utf8 64)) (description (string-utf8 256)) (link (string-utf8 128)))
  (let
    ((proposer tx-sender)
     (proposal-id (var-get proposal-id-nonce))
     (token-balance (default-to u0 (map-get? member-tokens proposer)))
     (current-height (unwrap-panic (get-block-info? height u0))))
    
    ;; Validate inputs
    (asserts! (> (len title) u0) err-invalid-title)
    (asserts! (> (len description) u0) err-invalid-description)
    (asserts! (> (len link) u0) err-invalid-link)
    
    ;; Check if proposer has enough tokens
    (asserts! (>= token-balance (var-get min-proposal-threshold)) err-not-enough-tokens)
    
    ;; Store the proposal
    (map-set proposals proposal-id {
      proposer: proposer,
      title: title,
      description: description,
      link: link,
      votes-for: u0,
      votes-against: u0,
      status: "active",
      execution-deadline: (+ current-height (var-get voting-period))
    })
    
    ;; Increment the proposal ID counter
    (var-set proposal-id-nonce (+ proposal-id u1))
    
    (ok proposal-id)))

;; Vote on a proposal
(define-public (vote (proposal-id uint) (vote-for bool))
  (let
    ((proposal (unwrap! (map-get? proposals proposal-id) err-proposal-not-found))
     (voter tx-sender)
     (token-balance (default-to u0 (map-get? member-tokens voter)))
     (vote-key {proposal-id: proposal-id, voter: voter})
     (current-height (unwrap-panic (get-block-info? height u0))))
    
    ;; Check if proposal is still active
    (asserts! (< current-height (get execution-deadline proposal)) err-proposal-ended)
    
    ;; Check if voter has already voted
    (asserts! (is-none (map-get? votes vote-key)) err-already-voted)
    
    ;; Record the vote
    (map-set votes vote-key true)
    
    ;; Update vote counts
    (if vote-for
      (ok (map-set proposals proposal-id (merge proposal {votes-for: (+ (get votes-for proposal) token-balance)})))
      (ok (map-set proposals proposal-id (merge proposal {votes-against: (+ (get votes-against proposal) token-balance)})))
    )
  )
)

;; Finalize a proposal
(define-public (finalize-proposal (proposal-id uint))
  (let
    ((proposal (unwrap! (map-get? proposals proposal-id) err-proposal-not-found))
     (current-height (unwrap-panic (get-block-info? height u0))))
    
    ;; Check if voting period has ended
    (asserts! (>= current-height (get execution-deadline proposal)) err-proposal-not-ended)
    
    ;; Update proposal status
    (ok (map-set proposals proposal-id 
      (merge proposal 
        {status: (if (> (get votes-for proposal) (get votes-against proposal)) "approved" "rejected")})))
  )
)

;; Get proposal details
(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id))

;; Get member token balance
(define-read-only (get-member-tokens (member principal))
  (default-to u0 (map-get? member-tokens member)))

;; Transfer tokens
(define-public (transfer-tokens (amount uint) (recipient principal))
  (let
    ((sender tx-sender)
     (sender-balance (default-to u0 (map-get? member-tokens sender)))
     (recipient-balance (default-to u0 (map-get? member-tokens recipient))))
    
    ;; Validate inputs
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (not (is-eq recipient 'SP000000000000000000002Q6VF78)) err-not-authorized)
    
    ;; Check if sender has enough tokens
    (asserts! (>= sender-balance amount) err-not-enough-tokens)
    
    ;; Update balances
    (map-set member-tokens sender (- sender-balance amount))
    (ok (map-set member-tokens recipient (+ recipient-balance amount)))
  )
)