;; title: real-time-sentiment-analysis
;; version: 1.0.0
;; summary: Multi-platform social listening with predictive brand crisis detection
;; description: This contract manages sentiment data collection, analysis, and crisis detection for brands across multiple platforms.

;; traits
;;

;; token definitions
;;

;; constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_SENTIMENT (err u101))
(define-constant ERR_INVALID_SCORE (err u102))
(define-constant ERR_BRAND_NOT_FOUND (err u103))
(define-constant ERR_INVALID_PLATFORM (err u104))
(define-constant ERR_RATE_LIMIT_EXCEEDED (err u105))
(define-constant ERR_CRISIS_THRESHOLD_INVALID (err u106))

(define-constant MAX_SENTIMENT_SCORE u100)
(define-constant MIN_SENTIMENT_SCORE u0)
(define-constant CRISIS_THRESHOLD u20)
(define-constant RATE_LIMIT_WINDOW u144) ;; blocks (approx 24 hours)
(define-constant MAX_SUBMISSIONS_PER_WINDOW u50)

;; Sentiment categories
(define-constant SENTIMENT_POSITIVE "positive")
(define-constant SENTIMENT_NEGATIVE "negative")
(define-constant SENTIMENT_NEUTRAL "neutral")

;; data vars
(define-data-var next-sentiment-id uint u1)
(define-data-var total-brands uint u0)
(define-data-var total-sentiment-entries uint u0)
(define-data-var crisis-alert-enabled bool true)

;; data maps
;; Store sentiment data with temporal indexing
(define-map sentiment-data
  { sentiment-id: uint }
  {
    brand-name: (string-ascii 64),
    sentiment-score: uint,
    sentiment-category: (string-ascii 16),
    platform: (string-ascii 32),
    timestamp: uint,
    submitter: principal,
    verified: bool
  }
)

;; Brand registry with aggregated sentiment metrics
(define-map brand-registry
  { brand-name: (string-ascii 64) }
  {
    total-entries: uint,
    average-sentiment: uint,
    last-update: uint,
    crisis-status: bool,
    owner: principal,
    platforms-count: uint
  }
)

;; Platform-specific brand sentiment tracking
(define-map platform-sentiment
  { brand-name: (string-ascii 64), platform: (string-ascii 32) }
  {
    total-entries: uint,
    average-sentiment: uint,
    last-sentiment: uint,
    last-update: uint
  }
)

;; Crisis alerts tracking
(define-map crisis-alerts
  { brand-name: (string-ascii 64), alert-id: uint }
  {
    alert-timestamp: uint,
    alert-score: uint,
    platform: (string-ascii 32),
    resolved: bool,
    resolver: (optional principal)
  }
)

;; Rate limiting for submissions
(define-map submission-rate-limit
  { submitter: principal, window-start: uint }
  { submission-count: uint }
)

;; Authorized data providers
(define-map authorized-providers
  { provider: principal }
  { authorized: bool, reputation-score: uint }
)

;; Sentiment trends (daily aggregates)
(define-map daily-sentiment-trends
  { brand-name: (string-ascii 64), date: uint }
  {
    average-sentiment: uint,
    total-entries: uint,
    positive-count: uint,
    negative-count: uint,
    neutral-count: uint
  }
)

;; public functions

;; Initialize a new brand for monitoring
(define-public (register-brand (brand-name (string-ascii 64)))
  (let ((existing-brand (map-get? brand-registry {brand-name: brand-name})))
    (asserts! (is-none existing-brand) (err u107)) ;; Brand already exists
    (map-set brand-registry 
      {brand-name: brand-name}
      {
        total-entries: u0,
        average-sentiment: u50, ;; neutral starting point
        last-update: stacks-block-height,
        crisis-status: false,
        owner: tx-sender,
        platforms-count: u0
      }
    )
    (var-set total-brands (+ (var-get total-brands) u1))
    (ok true)
  )
)

;; Submit sentiment data for a brand
(define-public (submit-sentiment-data 
  (brand-name (string-ascii 64))
  (sentiment-score uint)
  (sentiment-category (string-ascii 16))
  (platform (string-ascii 32))
  )
  (let 
    (
      (current-id (var-get next-sentiment-id))
      (brand-info (unwrap! (map-get? brand-registry {brand-name: brand-name}) ERR_BRAND_NOT_FOUND))
    )
    ;; Validate inputs
    (asserts! (and (>= sentiment-score MIN_SENTIMENT_SCORE) (<= sentiment-score MAX_SENTIMENT_SCORE)) ERR_INVALID_SCORE)
    (asserts! (is-valid-sentiment-category sentiment-category) ERR_INVALID_SENTIMENT)
    (asserts! (> (len platform) u0) ERR_INVALID_PLATFORM)
    
    ;; Check rate limiting
    (try! (check-rate-limit tx-sender))
    
    ;; Store sentiment data
    (map-set sentiment-data
      {sentiment-id: current-id}
      {
        brand-name: brand-name,
        sentiment-score: sentiment-score,
        sentiment-category: sentiment-category,
        platform: platform,
        timestamp: stacks-block-height,
        submitter: tx-sender,
        verified: (is-authorized-provider tx-sender)
      }
    )
    
    ;; Update brand registry
    (try! (update-brand-metrics brand-name sentiment-score platform))
    
    ;; Update platform-specific tracking
    (unwrap-panic (update-platform-sentiment brand-name platform sentiment-score))
    
    ;; Check for crisis conditions
    (try! (check-crisis-conditions brand-name sentiment-score platform))
    
    ;; Update daily trends
    (unwrap-panic (update-daily-trends brand-name sentiment-score sentiment-category))
    
    ;; Update counters
    (var-set next-sentiment-id (+ current-id u1))
    (var-set total-sentiment-entries (+ (var-get total-sentiment-entries) u1))
    
    (ok current-id)
  )
)

;; Authorize a data provider
(define-public (authorize-provider (provider principal) (reputation-score uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set authorized-providers
      {provider: provider}
      {authorized: true, reputation-score: reputation-score}
    )
    (ok true)
  )
)

;; Resolve a crisis alert
(define-public (resolve-crisis-alert (brand-name (string-ascii 64)) (alert-id uint))
  (let ((alert-info (map-get? crisis-alerts {brand-name: brand-name, alert-id: alert-id})))
    (asserts! (is-some alert-info) (err u108)) ;; Alert not found
    (map-set crisis-alerts
      {brand-name: brand-name, alert-id: alert-id}
      (merge (unwrap-panic alert-info)
        {
          resolved: true,
          resolver: (some tx-sender)
        }
      )
    )
    ;; Update brand crisis status if this was the last unresolved alert
    (try! (update-brand-crisis-status brand-name))
    (ok true)
  )
)

;; read only functions

;; Get sentiment data by ID
(define-read-only (get-sentiment-data (sentiment-id uint))
  (map-get? sentiment-data {sentiment-id: sentiment-id})
)

;; Get brand information
(define-read-only (get-brand-info (brand-name (string-ascii 64)))
  (map-get? brand-registry {brand-name: brand-name})
)

;; Get platform-specific sentiment for a brand
(define-read-only (get-platform-sentiment (brand-name (string-ascii 64)) (platform (string-ascii 32)))
  (map-get? platform-sentiment {brand-name: brand-name, platform: platform})
)

;; Get crisis alerts for a brand
(define-read-only (get-crisis-alert (brand-name (string-ascii 64)) (alert-id uint))
  (map-get? crisis-alerts {brand-name: brand-name, alert-id: alert-id})
)

;; Get daily sentiment trends
(define-read-only (get-daily-trends (brand-name (string-ascii 64)) (date uint))
  (map-get? daily-sentiment-trends {brand-name: brand-name, date: date})
)

;; Check if a provider is authorized
(define-read-only (is-authorized-provider (provider principal))
  (default-to false (get authorized (map-get? authorized-providers {provider: provider})))
)

;; Get contract statistics
(define-read-only (get-contract-stats)
  {
    total-brands: (var-get total-brands),
    total-sentiment-entries: (var-get total-sentiment-entries),
    next-sentiment-id: (var-get next-sentiment-id),
    crisis-alert-enabled: (var-get crisis-alert-enabled)
  }
)

;; private functions

;; Validate sentiment category
(define-private (is-valid-sentiment-category (category (string-ascii 16)))
  (or
    (is-eq category SENTIMENT_POSITIVE)
    (is-eq category SENTIMENT_NEGATIVE)
    (is-eq category SENTIMENT_NEUTRAL)
  )
)

;; Check rate limiting for submissions
(define-private (check-rate-limit (submitter principal))
  (let 
    (
      (window-start (/ stacks-block-height RATE_LIMIT_WINDOW))
      (current-count (default-to u0 (get submission-count 
        (map-get? submission-rate-limit {submitter: submitter, window-start: window-start}))))
    )
    (asserts! (< current-count MAX_SUBMISSIONS_PER_WINDOW) ERR_RATE_LIMIT_EXCEEDED)
    (map-set submission-rate-limit
      {submitter: submitter, window-start: window-start}
      {submission-count: (+ current-count u1)}
    )
    (ok true)
  )
)

;; Update brand metrics with new sentiment data
(define-private (update-brand-metrics (brand-name (string-ascii 64)) (new-score uint) (platform (string-ascii 32)))
  (let 
    (
      (brand-info (unwrap! (map-get? brand-registry {brand-name: brand-name}) ERR_BRAND_NOT_FOUND))
      (total-entries (get total-entries brand-info))
      (current-average (get average-sentiment brand-info))
      (new-total (+ total-entries u1))
      (new-average (/ (+ (* current-average total-entries) new-score) new-total))
    )
    (map-set brand-registry
      {brand-name: brand-name}
      (merge brand-info
        {
          total-entries: new-total,
          average-sentiment: new-average,
          last-update: stacks-block-height
        }
      )
    )
    (ok true)
  )
)

;; Update platform-specific sentiment tracking
(define-private (update-platform-sentiment (brand-name (string-ascii 64)) (platform (string-ascii 32)) (sentiment-score uint))
  (begin
    (match (map-get? platform-sentiment {brand-name: brand-name, platform: platform})
      platform-data
      (let 
        (
          (total-entries (get total-entries platform-data))
          (current-average (get average-sentiment platform-data))
          (new-total (+ total-entries u1))
          (new-average (/ (+ (* current-average total-entries) sentiment-score) new-total))
        )
        (map-set platform-sentiment
          {brand-name: brand-name, platform: platform}
          {
            total-entries: new-total,
            average-sentiment: new-average,
            last-sentiment: sentiment-score,
            last-update: stacks-block-height
          }
        )
      )
      ;; First entry for this brand-platform combination
      (map-set platform-sentiment
        {brand-name: brand-name, platform: platform}
        {
          total-entries: u1,
          average-sentiment: sentiment-score,
          last-sentiment: sentiment-score,
          last-update: stacks-block-height
        }
      )
    )
    (ok true)
  )
)

;; Check for crisis conditions and trigger alerts
(define-private (check-crisis-conditions (brand-name (string-ascii 64)) (sentiment-score uint) (platform (string-ascii 32)))
  (begin
    (if (and (var-get crisis-alert-enabled) (<= sentiment-score CRISIS_THRESHOLD))
      (let 
        (
          (alert-id (+ (var-get next-sentiment-id) u1000)) ;; Offset for alert IDs
        )
        (map-set crisis-alerts
          {brand-name: brand-name, alert-id: alert-id}
          {
            alert-timestamp: stacks-block-height,
            alert-score: sentiment-score,
            platform: platform,
            resolved: false,
            resolver: none
          }
        )
        ;; Update brand crisis status
        (let ((brand-info (unwrap! (map-get? brand-registry {brand-name: brand-name}) ERR_BRAND_NOT_FOUND)))
          (map-set brand-registry
            {brand-name: brand-name}
            (merge brand-info {crisis-status: true})
          )
        )
      )
      true ;; No crisis condition
    )
    (ok true)
  )
)

;; Update brand crisis status based on unresolved alerts
(define-private (update-brand-crisis-status (brand-name (string-ascii 64)))
  ;; This is a simplified version - in a full implementation,
  ;; you would iterate through all alerts for the brand
  (let ((brand-info (unwrap! (map-get? brand-registry {brand-name: brand-name}) ERR_BRAND_NOT_FOUND)))
    (map-set brand-registry
      {brand-name: brand-name}
      (merge brand-info {crisis-status: false}) ;; Simplified - assume resolved
    )
    (ok true)
  )
)

;; Update daily sentiment trends
(define-private (update-daily-trends (brand-name (string-ascii 64)) (sentiment-score uint) (sentiment-category (string-ascii 16)))
  (let 
    (
      (current-date (/ stacks-block-height u144)) ;; Approximate daily buckets
      (existing-trend (map-get? daily-sentiment-trends {brand-name: brand-name, date: current-date}))
    )
    (match existing-trend
      trend-data
      (let 
        (
          (total-entries (get total-entries trend-data))
          (current-average (get average-sentiment trend-data))
          (new-total (+ total-entries u1))
          (new-average (/ (+ (* current-average total-entries) sentiment-score) new-total))
          (positive-count (if (is-eq sentiment-category SENTIMENT_POSITIVE) 
                           (+ (get positive-count trend-data) u1) 
                           (get positive-count trend-data)))
          (negative-count (if (is-eq sentiment-category SENTIMENT_NEGATIVE) 
                           (+ (get negative-count trend-data) u1) 
                           (get negative-count trend-data)))
          (neutral-count (if (is-eq sentiment-category SENTIMENT_NEUTRAL) 
                          (+ (get neutral-count trend-data) u1) 
                          (get neutral-count trend-data)))
        )
        (map-set daily-sentiment-trends
          {brand-name: brand-name, date: current-date}
          {
            average-sentiment: new-average,
            total-entries: new-total,
            positive-count: positive-count,
            negative-count: negative-count,
            neutral-count: neutral-count
          }
        )
      )
      ;; First entry for this day
      (map-set daily-sentiment-trends
        {brand-name: brand-name, date: current-date}
        {
          average-sentiment: sentiment-score,
          total-entries: u1,
          positive-count: (if (is-eq sentiment-category SENTIMENT_POSITIVE) u1 u0),
          negative-count: (if (is-eq sentiment-category SENTIMENT_NEGATIVE) u1 u0),
          neutral-count: (if (is-eq sentiment-category SENTIMENT_NEUTRAL) u1 u0)
        }
      )
    )
    (ok true)
  )
)
