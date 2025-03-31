;; FashionDAO - Decentralized Autonomous Organization for fashion designers
(define-fungible-token fashion-dao-token)

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

;; Error codes
(define-constant err-not-enough-tokens (err u100))
(define-constant err-proposal-not-found (err u101))
(define-constant err-already-voted (err u102))
(define-constant err-proposal-ended (err u103))

;; Initialize tokens for founder
(define-public (initialize-tokens (amount uint))
  (begin
    (asserts! (is-eq tx-sender (contract-owner)) err-not-authorized)
    (try! (ft-mint? fashion-dao-token amount tx-sender))
    (ok true)))

;; Create a new proposal
(define-public (create-proposal (title (string-utf8 64)) (description (string-utf8 256)) (link (string-utf8 128)))
  (let
    ((proposer tx-sender)
     (proposal-id (var-get proposal-id-nonce))
     (token-balance (default-to u0 (map-get? member-tokens proposer))))
    
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
      execution-deadline: (+ block-height (var-get voting-period))
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
     (vote-key {proposal-id: proposal-id, voter: voter}))
    
    ;; Check if proposal is still active
    (asserts! (< block-height (get execution-deadline proposal)) err-proposal-ended)
    
    ;; Check if voter has already voted
    (asserts! (is-none (map-get? votes vote-key)) err-already-voted)
    
    ;; Record the vote
    (map-set votes vote-key true)
    
    ;; Update vote counts
    (if vote-for
      (map-set proposals proposal-id (merge proposal {votes-for: (+ (get votes-for proposal) token-balance)}))
      (map-set proposals proposal-id (merge proposal {votes-against: (+ (get votes-against proposal) token-balance)}))
    )
    
    (ok true)))

;; Finalize a proposal
(define-public (finalize-proposal (proposal-id uint))
  (let
    ((proposal (unwrap! (map-get? proposals proposal-id) err-proposal-not-found)))
    
    ;; Check if voting period has ended
    (asserts! (>= block-height (get execution-deadline proposal)) err-proposal-not-ended)
    
    ;; Update proposal status
    (map-set proposals proposal-id 
      (merge proposal 
        {status: (if (> (get votes-for proposal) (get votes-against proposal)) "approved" "rejected")}))
    
    (ok true)))

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
    
    ;; Check if sender has enough tokens
    (asserts! (>= sender-balance amount) err-not-enough-tokens)
    
    ;; Update balances
    (map-set member-tokens sender (- sender-balance amount))
    (map-set member-tokens recipient (+ recipient-balance amount))
    
    (ok true)))

;; Contract owner for admin functions
(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u403))
(define-constant err-proposal-not-ended (err u104))