;; title: competitive-intelligence-engine
;; version: 1.0.0
;; summary: Automated competitor strategy analysis and market positioning insights
;; description: This contract handles competitor analysis, market positioning data, and strategic intelligence reporting.

;; traits
;;

;; token definitions
;;

;; constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_COMPETITOR_NOT_FOUND (err u201))
(define-constant ERR_INVALID_MARKET_SHARE (err u202))
(define-constant ERR_INVALID_SCORE (err u203))
(define-constant ERR_REPORT_NOT_FOUND (err u204))
(define-constant ERR_INSUFFICIENT_DATA (err u205))
(define-constant ERR_MARKET_SEGMENT_NOT_FOUND (err u206))
(define-constant ERR_ACCESS_DENIED (err u207))

(define-constant MAX_MARKET_SHARE u100)
(define-constant MIN_MARKET_SHARE u0)
(define-constant MAX_PERFORMANCE_SCORE u100)
(define-constant MIN_PERFORMANCE_SCORE u0)
(define-constant MIN_DATA_POINTS_FOR_ANALYSIS u3)
(define-constant REPORT_VALIDITY_PERIOD u1008) ;; blocks (approx 1 week)

;; Market segments
(define-constant SEGMENT_TECHNOLOGY "technology")
(define-constant SEGMENT_RETAIL "retail")
(define-constant SEGMENT_FINANCIAL "financial")
(define-constant SEGMENT_HEALTHCARE "healthcare")
(define-constant SEGMENT_AUTOMOTIVE "automotive")

;; data vars
(define-data-var next-competitor-id uint u1)
(define-data-var next-report-id uint u1)
(define-data-var total-competitors uint u0)
(define-data-var total-market-segments uint u0)
(define-data-var intelligence-system-active bool true)

;; data maps
;; Competitor registry with basic information
(define-map competitor-registry
  { competitor-id: uint }
  {
    competitor-name: (string-ascii 64),
    market-segment: (string-ascii 32),
    registration-date: uint,
    last-update: uint,
    data-points-count: uint,
    verified: bool,
    registrant: principal
  }
)

;; Competitor performance metrics
(define-map competitor-metrics
  { competitor-name: (string-ascii 64), metric-period: uint }
  {
    market-share: uint,
    performance-score: uint,
    growth-rate: int,
    revenue-estimate: uint,
    customer-satisfaction: uint,
    innovation-index: uint,
    timestamp: uint,
    data-source: (string-ascii 64)
  }
)

;; Market segment analysis
(define-map market-segments
  { segment-name: (string-ascii 32) }
  {
    total-competitors: uint,
    market-size: uint,
    growth-trend: int,
    leader-name: (string-ascii 64),
    leader-share: uint,
    last-analysis: uint,
    volatility-index: uint
  }
)

;; Competitive intelligence reports
(define-map intelligence-reports
  { report-id: uint }
  {
    report-type: (string-ascii 32),
    target-competitor: (string-ascii 64),
    market-segment: (string-ascii 32),
    analysis-period: uint,
    key-insights: (string-ascii 256),
    competitive-score: uint,
    threat-level: (string-ascii 16),
    generated-date: uint,
    expires-at: uint,
    analyst: principal,
    access-level: (string-ascii 16)
  }
)

;; Strategic positioning data
(define-map strategic-positioning
  { competitor-name: (string-ascii 64), positioning-date: uint }
  {
    market-position: uint,
    competitive-advantages: (string-ascii 128),
    weaknesses: (string-ascii 128),
    strategic-focus: (string-ascii 64),
    target-market: (string-ascii 64),
    differentiation-score: uint
  }
)

;; Access control for sensitive intelligence
(define-map intelligence-access
  { user: principal, access-level: (string-ascii 16) }
  { granted-by: principal, granted-date: uint, expires-at: uint }
)

;; Competitor comparison matrix
(define-map competitor-comparisons
  { comparison-id: uint }
  {
    competitor-a: (string-ascii 64),
    competitor-b: (string-ascii 64),
    market-segment: (string-ascii 32),
    comparison-metrics: (string-ascii 256),
    winner-assessment: (string-ascii 64),
    confidence-score: uint,
    analysis-date: uint
  }
)

;; Market trend analysis
(define-map market-trends
  { segment-name: (string-ascii 32), trend-period: uint }
  {
    trend-direction: (string-ascii 16),
    growth-percentage: int,
    key-drivers: (string-ascii 128),
    disruption-risk: uint,
    opportunity-score: uint,
    analysis-date: uint
  }
)

;; public functions

;; Register a new competitor for analysis
(define-public (register-competitor 
  (competitor-name (string-ascii 64))
  (market-segment (string-ascii 32))
  )
  (let 
    (
      (competitor-id (var-get next-competitor-id))
    )
    ;; Validate market segment
    (asserts! (is-valid-market-segment market-segment) ERR_MARKET_SEGMENT_NOT_FOUND)
    
    ;; Store competitor information
    (map-set competitor-registry
      {competitor-id: competitor-id}
      {
        competitor-name: competitor-name,
        market-segment: market-segment,
        registration-date: stacks-block-height,
        last-update: stacks-block-height,
        data-points-count: u0,
        verified: false,
        registrant: tx-sender
      }
    )
    
    ;; Update counters
    (var-set next-competitor-id (+ competitor-id u1))
    (var-set total-competitors (+ (var-get total-competitors) u1))
    
    ;; Initialize or update market segment
    (unwrap-panic (update-market-segment-stats market-segment))
    
    (ok competitor-id)
  )
)

;; Submit competitor performance data
(define-public (submit-competitor-metrics
  (competitor-name (string-ascii 64))
  (market-share uint)
  (performance-score uint)
  (growth-rate int)
  (revenue-estimate uint)
  (customer-satisfaction uint)
  (innovation-index uint)
  (data-source (string-ascii 64))
  )
  (let
    (
      (metric-period (/ stacks-block-height u144)) ;; Daily periods
    )
    ;; Validate inputs
    (asserts! (and (>= market-share MIN_MARKET_SHARE) (<= market-share MAX_MARKET_SHARE)) ERR_INVALID_MARKET_SHARE)
    (asserts! (and (>= performance-score MIN_PERFORMANCE_SCORE) (<= performance-score MAX_PERFORMANCE_SCORE)) ERR_INVALID_SCORE)
    (asserts! (<= customer-satisfaction u100) ERR_INVALID_SCORE)
    (asserts! (<= innovation-index u100) ERR_INVALID_SCORE)
    
    ;; Store metrics
    (map-set competitor-metrics
      {competitor-name: competitor-name, metric-period: metric-period}
      {
        market-share: market-share,
        performance-score: performance-score,
        growth-rate: growth-rate,
        revenue-estimate: revenue-estimate,
        customer-satisfaction: customer-satisfaction,
        innovation-index: innovation-index,
        timestamp: stacks-block-height,
        data-source: data-source
      }
    )
    
    ;; Update competitor data points count
    (unwrap-panic (increment-competitor-data-points competitor-name))
    
    (ok true)
  )
)

;; Generate competitive intelligence report
(define-public (generate-intelligence-report
  (target-competitor (string-ascii 64))
  (market-segment (string-ascii 32))
  (report-type (string-ascii 32))
  (key-insights (string-ascii 256))
  (threat-level (string-ascii 16))
  (access-level (string-ascii 16))
  )
  (let
    (
      (report-id (var-get next-report-id))
      (competitive-score (calculate-competitive-score target-competitor))
    )
    ;; Check if user has authorization to generate reports
    (asserts! (has-intelligence-access tx-sender "analyst") ERR_ACCESS_DENIED)
    
    ;; Store intelligence report
    (map-set intelligence-reports
      {report-id: report-id}
      {
        report-type: report-type,
        target-competitor: target-competitor,
        market-segment: market-segment,
        analysis-period: u30, ;; Last 30 periods
        key-insights: key-insights,
        competitive-score: competitive-score,
        threat-level: threat-level,
        generated-date: stacks-block-height,
        expires-at: (+ stacks-block-height REPORT_VALIDITY_PERIOD),
        analyst: tx-sender,
        access-level: access-level
      }
    )
    
    ;; Update report counter
    (var-set next-report-id (+ report-id u1))
    
    (ok report-id)
  )
)

;; Update strategic positioning for a competitor
(define-public (update-strategic-positioning
  (competitor-name (string-ascii 64))
  (market-position uint)
  (competitive-advantages (string-ascii 128))
  (weaknesses (string-ascii 128))
  (strategic-focus (string-ascii 64))
  (target-market (string-ascii 64))
  (differentiation-score uint)
  )
  (begin
    ;; Validate inputs
    (asserts! (<= market-position u10) ERR_INVALID_SCORE) ;; Position rank 1-10
    (asserts! (<= differentiation-score u100) ERR_INVALID_SCORE)
    
    ;; Store positioning data
    (map-set strategic-positioning
      {competitor-name: competitor-name, positioning-date: stacks-block-height}
      {
        market-position: market-position,
        competitive-advantages: competitive-advantages,
        weaknesses: weaknesses,
        strategic-focus: strategic-focus,
        target-market: target-market,
        differentiation-score: differentiation-score
      }
    )
    
    (ok true)
  )
)

;; Grant intelligence access to a user
(define-public (grant-intelligence-access
  (user principal)
  (access-level (string-ascii 16))
  (validity-period uint)
  )
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
    (map-set intelligence-access
      {user: user, access-level: access-level}
      {
        granted-by: tx-sender,
        granted-date: stacks-block-height,
        expires-at: (+ stacks-block-height validity-period)
      }
    )
    
    (ok true)
  )
)

;; Create competitor comparison analysis
(define-public (create-competitor-comparison
  (competitor-a (string-ascii 64))
  (competitor-b (string-ascii 64))
  (market-segment (string-ascii 32))
  (comparison-metrics (string-ascii 256))
  (winner-assessment (string-ascii 64))
  (confidence-score uint)
  )
  (let
    (
      (comparison-id (+ (var-get next-report-id) u10000)) ;; Offset for comparison IDs
    )
    ;; Validate confidence score
    (asserts! (<= confidence-score u100) ERR_INVALID_SCORE)
    
    ;; Store comparison
    (map-set competitor-comparisons
      {comparison-id: comparison-id}
      {
        competitor-a: competitor-a,
        competitor-b: competitor-b,
        market-segment: market-segment,
        comparison-metrics: comparison-metrics,
        winner-assessment: winner-assessment,
        confidence-score: confidence-score,
        analysis-date: stacks-block-height
      }
    )
    
    (ok comparison-id)
  )
)

;; read only functions

;; Get competitor information by ID
(define-read-only (get-competitor-info (competitor-id uint))
  (map-get? competitor-registry {competitor-id: competitor-id})
)

;; Get competitor metrics for a specific period
(define-read-only (get-competitor-metrics (competitor-name (string-ascii 64)) (metric-period uint))
  (map-get? competitor-metrics {competitor-name: competitor-name, metric-period: metric-period})
)

;; Get intelligence report
(define-read-only (get-intelligence-report (report-id uint))
  (map-get? intelligence-reports {report-id: report-id})
)

;; Get market segment analysis
(define-read-only (get-market-segment-analysis (segment-name (string-ascii 32)))
  (map-get? market-segments {segment-name: segment-name})
)

;; Get strategic positioning data
(define-read-only (get-strategic-positioning (competitor-name (string-ascii 64)) (positioning-date uint))
  (map-get? strategic-positioning {competitor-name: competitor-name, positioning-date: positioning-date})
)

;; Get competitor comparison
(define-read-only (get-competitor-comparison (comparison-id uint))
  (map-get? competitor-comparisons {comparison-id: comparison-id})
)

;; Get market trends
(define-read-only (get-market-trends (segment-name (string-ascii 32)) (trend-period uint))
  (map-get? market-trends {segment-name: segment-name, trend-period: trend-period})
)

;; Check if user has intelligence access
(define-read-only (has-intelligence-access (user principal) (access-level (string-ascii 16)))
  (match (map-get? intelligence-access {user: user, access-level: access-level})
    access-info
    (> (get expires-at access-info) stacks-block-height)
    false
  )
)

;; Get contract statistics
(define-read-only (get-contract-stats)
  {
    total-competitors: (var-get total-competitors),
    total-market-segments: (var-get total-market-segments),
    next-competitor-id: (var-get next-competitor-id),
    next-report-id: (var-get next-report-id),
    intelligence-system-active: (var-get intelligence-system-active)
  }
)

;; private functions

;; Validate market segment
(define-private (is-valid-market-segment (segment (string-ascii 32)))
  (or
    (is-eq segment SEGMENT_TECHNOLOGY)
    (is-eq segment SEGMENT_RETAIL)
    (is-eq segment SEGMENT_FINANCIAL)
    (is-eq segment SEGMENT_HEALTHCARE)
    (is-eq segment SEGMENT_AUTOMOTIVE)
  )
)

;; Update market segment statistics
(define-private (update-market-segment-stats (segment-name (string-ascii 32)))
  (begin
    (match (map-get? market-segments {segment-name: segment-name})
      segment-data
      (map-set market-segments
        {segment-name: segment-name}
        (merge segment-data
          {
            total-competitors: (+ (get total-competitors segment-data) u1),
            last-analysis: stacks-block-height
          }
        )
      )
      ;; First competitor in this segment
      (begin
        (map-set market-segments
          {segment-name: segment-name}
          {
            total-competitors: u1,
            market-size: u0, ;; To be updated with actual data
            growth-trend: 0, ;; Neutral starting point
            leader-name: "",
            leader-share: u0,
            last-analysis: stacks-block-height,
            volatility-index: u50 ;; Moderate volatility default
          }
        )
        (var-set total-market-segments (+ (var-get total-market-segments) u1))
      )
    )
    (ok true)
  )
)

;; Increment competitor data points count
(define-private (increment-competitor-data-points (competitor-name (string-ascii 64)))
  ;; This is a simplified version - in practice, you'd find the competitor by name
  ;; and update their data points count in the registry
  (ok true)
)

;; Calculate competitive score based on available metrics
(define-private (calculate-competitive-score (competitor-name (string-ascii 64)))
  (let
    (
      (current-period (/ stacks-block-height u144))
      (metrics (map-get? competitor-metrics {competitor-name: competitor-name, metric-period: current-period}))
    )
    (match metrics
      metric-data
      (let
        (
          (market-share (get market-share metric-data))
          (performance-score (get performance-score metric-data))
          (customer-satisfaction (get customer-satisfaction metric-data))
          (innovation-index (get innovation-index metric-data))
        )
        ;; Weighted average of key metrics
        (/ (+ (* market-share u3) (* performance-score u2) customer-satisfaction innovation-index) u7)
      )
      u50 ;; Default neutral score if no data available
    )
  )
)
