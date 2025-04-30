;; fitgrid-core
;; This contract serves as the central hub for the FitGrid platform, handling 
;; user registries, profile management, fitness goal tracking, and social connections.
;; Users can create profiles, set fitness goals, track progress, connect with others,
;; join groups, and participate in challenges to earn rewards.

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-USER-ALREADY-EXISTS (err u101))
(define-constant ERR-USER-NOT-FOUND (err u102))
(define-constant ERR-CONNECTION-ALREADY-EXISTS (err u103))
(define-constant ERR-CONNECTION-NOT-FOUND (err u104))
(define-constant ERR-GROUP-NOT-FOUND (err u105))
(define-constant ERR-ALREADY-GROUP-MEMBER (err u106))
(define-constant ERR-NOT-GROUP-MEMBER (err u107))
(define-constant ERR-CHALLENGE-NOT-FOUND (err u108))
(define-constant ERR-ALREADY-JOINED-CHALLENGE (err u109))
(define-constant ERR-MILESTONE-INVALID (err u110))
(define-constant ERR-CHALLENGE-ENDED (err u111))
(define-constant ERR-INVALID-PARAMETER (err u112))

;; Data structures

;; User profile data
(define-map users 
  { user: principal }
  {
    username: (string-utf8 50),
    bio: (string-utf8 500),
    created-at: uint,
    fitness-level: uint,
    is-public: bool
  }
)

;; User fitness goals
(define-map fitness-goals
  { user: principal }
  {
    weight-goal: (optional uint),
    cardio-goal-minutes: (optional uint),
    strength-goal-sessions: (optional uint),
    target-date: (optional uint),
    created-at: uint,
    last-updated: uint
  }
)

;; User current stats
(define-map fitness-stats
  { user: principal }
  {
    current-weight: (optional uint),
    weekly-cardio-minutes: uint,
    weekly-strength-sessions: uint,
    total-workouts: uint,
    last-updated: uint
  }
)

;; User workout preferences
(define-map workout-preferences
  { user: principal }
  {
    preferred-activities: (list 10 (string-utf8 30)),
    preferred-intensity: uint,
    preferred-duration: uint,
    preferred-time: (string-utf8 20)
  }
)

;; User connections (social graph)
(define-map connections
  { user: principal, connection: principal }
  {
    status: (string-utf8 20), ;; "pending", "connected", "blocked"
    connected-at: uint
  }
)

;; Fitness groups
(define-map fitness-groups
  { group-id: uint }
  {
    name: (string-utf8 50),
    description: (string-utf8 500),
    creator: principal,
    created-at: uint,
    max-members: uint,
    focus-area: (string-utf8 30),
    is-public: bool
  }
)

;; Group membership
(define-map group-members
  { group-id: uint, user: principal }
  {
    joined-at: uint,
    role: (string-utf8 20) ;; "member", "admin"
  }
)

;; Fitness challenges
(define-map fitness-challenges
  { challenge-id: uint }
  {
    name: (string-utf8 50),
    description: (string-utf8 500),
    creator: principal,
    start-date: uint,
    end-date: uint,
    challenge-type: (string-utf8 30),
    target-value: uint,
    reward-points: uint,
    is-active: bool
  }
)

;; Challenge participation
(define-map challenge-participants
  { challenge-id: uint, user: principal }
  {
    joined-at: uint,
    current-progress: uint,
    completed: bool,
    completed-at: (optional uint)
  }
)

;; Achievements and rewards
(define-map user-achievements
  { user: principal, achievement-id: uint }
  {
    name: (string-utf8 50),
    description: (string-utf8 500),
    earned-at: uint,
    points: uint
  }
)

;; Counter for group IDs
(define-data-var next-group-id uint u1)

;; Counter for challenge IDs
(define-data-var next-challenge-id uint u1)

;; Counter for achievement IDs
(define-data-var next-achievement-id uint u1)

;; Private functions

;; Helper to get current block height as timestamp
(define-private (get-current-time)
  block-height
)

;; Check if a user exists
(define-private (user-exists (user principal))
  (is-some (map-get? users {user: user}))
)

;; Check if connection exists between two users
(define-private (connection-exists (user-1 principal) (user-2 principal))
  (is-some (map-get? connections {user: user-1, connection: user-2}))
)

;; Check if user is authorized
(define-private (is-self-or-contract-owner (user principal))
  (or
    (is-eq tx-sender user)
    (is-eq tx-sender (contract-owner))
  )
)

;; Check if user is in group
(define-private (is-group-member (group-id uint) (user principal))
  (is-some (map-get? group-members {group-id: group-id, user: user}))
)

;; Check if user has joined a challenge
(define-private (has-joined-challenge (challenge-id uint) (user principal))
  (is-some (map-get? challenge-participants {challenge-id: challenge-id, user: user}))
)

;; Calculate achievement based on fitness metrics
(define-private (check-achievement-milestone (user principal))
  (let (
    (stats (unwrap! (map-get? fitness-stats {user: user}) false))
    (goals (unwrap! (map-get? fitness-goals {user: user}) false))
  )
    (if (and (> (get total-workouts stats) u50) (is-some (get weight-goal goals)))
      (grant-achievement user "50 Workouts Completed" "Completed 50 workout sessions" u50)
      false
    )
  )
)

;; Grant achievement to user
(define-private (grant-achievement (user principal) (name (string-utf8 50)) (description (string-utf8 500)) (points uint))
  (let (
    (achievement-id (var-get next-achievement-id))
  )
    (map-set user-achievements 
      {user: user, achievement-id: achievement-id}
      {
        name: name,
        description: description,
        earned-at: (get-current-time),
        points: points
      }
    )
    (var-set next-achievement-id (+ achievement-id u1))
    true
  )
)

;; Read-only functions

;; Get user profile
(define-read-only (get-user-profile (user principal))
  (map-get? users {user: user})
)

;; Get user fitness goals
(define-read-only (get-fitness-goals (user principal))
  (map-get? fitness-goals {user: user})
)

;; Get user fitness stats
(define-read-only (get-fitness-stats (user principal))
  (map-get? fitness-stats {user: user})
)

;; Get user workout preferences
(define-read-only (get-workout-preferences (user principal))
  (map-get? workout-preferences {user: user})
)

;; Check if two users are connected
(define-read-only (are-users-connected (user-1 principal) (user-2 principal))
  (and
    (is-some (map-get? connections {user: user-1, connection: user-2}))
    (is-eq (get status (default-to {status: "", connected-at: u0} 
      (map-get? connections {user: user-1, connection: user-2}))) "connected")
  )
)

;; Get group details
(define-read-only (get-group-details (group-id uint))
  (map-get? fitness-groups {group-id: group-id})
)

;; Get challenge details
(define-read-only (get-challenge-details (challenge-id uint))
  (map-get? fitness-challenges {challenge-id: challenge-id})
)

;; Get user achievements
(define-read-only (get-user-achievements (user principal))
  (map-get? user-achievements {user: user, achievement-id: u0})
)

;; Check if challenge is active
(define-read-only (is-challenge-active (challenge-id uint))
  (let (
    (challenge (map-get? fitness-challenges {challenge-id: challenge-id}))
  )
    (and 
      (is-some challenge) 
      (get is-active (default-to {is-active: false} challenge))
    )
  )
)

;; Public functions

;; Register new user
(define-public (register-user (username (string-utf8 50)) (bio (string-utf8 500)) (fitness-level uint) (is-public bool))
  (let (
    (user tx-sender)
    (current-time (get-current-time))
  )
    (asserts! (not (user-exists user)) ERR-USER-ALREADY-EXISTS)
    (asserts! (> (len username) u0) ERR-INVALID-PARAMETER)
    (asserts! (<= fitness-level u10) ERR-INVALID-PARAMETER)

    ;; Create user profile
    (map-set users 
      {user: user}
      {
        username: username,
        bio: bio,
        created-at: current-time,
        fitness-level: fitness-level,
        is-public: is-public
      }
    )

    ;; Initialize fitness goals (empty)
    (map-set fitness-goals
      {user: user}
      {
        weight-goal: none,
        cardio-goal-minutes: none,
        strength-goal-sessions: none,
        target-date: none,
        created-at: current-time,
        last-updated: current-time
      }
    )

    ;; Initialize fitness stats (empty)
    (map-set fitness-stats
      {user: user}
      {
        current-weight: none,
        weekly-cardio-minutes: u0,
        weekly-strength-sessions: u0,
        total-workouts: u0,
        last-updated: current-time
      }
    )

    ;; Initialize workout preferences (empty)
    (map-set workout-preferences
      {user: user}
      {
        preferred-activities: (list),
        preferred-intensity: u0,
        preferred-duration: u0,
        preferred-time: ""
      }
    )

    (ok true)
  )
)

;; Update user profile
(define-public (update-user-profile (username (string-utf8 50)) (bio (string-utf8 500)) (fitness-level uint) (is-public bool))
  (let (
    (user tx-sender)
  )
    (asserts! (user-exists user) ERR-USER-NOT-FOUND)
    (asserts! (> (len username) u0) ERR-INVALID-PARAMETER)
    (asserts! (<= fitness-level u10) ERR-INVALID-PARAMETER)

    (map-set users 
      {user: user}
      {
        username: username,
        bio: bio,
        created-at: (get created-at (default-to {created-at: u0} (map-get? users {user: user}))),
        fitness-level: fitness-level,
        is-public: is-public
      }
    )

    (ok true)
  )
)

;; Set fitness goals
(define-public (set-fitness-goals 
  (weight-goal (optional uint)) 
  (cardio-goal-minutes (optional uint)) 
  (strength-goal-sessions (optional uint))
  (target-date (optional uint))
)
  (let (
    (user tx-sender)
    (current-time (get-current-time))
  )
    (asserts! (user-exists user) ERR-USER-NOT-FOUND)

    (map-set fitness-goals
      {user: user}
      {
        weight-goal: weight-goal,
        cardio-goal-minutes: cardio-goal-minutes,
        strength-goal-sessions: strength-goal-sessions,
        target-date: target-date,
        created-at: (get created-at (default-to {created-at: current-time} (map-get? fitness-goals {user: user}))),
        last-updated: current-time
      }
    )

    (ok true)
  )
)

;; Update fitness stats
(define-public (update-fitness-stats 
  (current-weight (optional uint)) 
  (weekly-cardio-minutes uint) 
  (weekly-strength-sessions uint)
  (workout-completed bool)
)
  (let (
    (user tx-sender)
    (current-time (get-current-time))
    (current-stats (default-to 
      {current-weight: none, weekly-cardio-minutes: u0, weekly-strength-sessions: u0, total-workouts: u0, last-updated: u0} 
      (map-get? fitness-stats {user: user})))
    (new-total-workouts (if workout-completed (+ (get total-workouts current-stats) u1) (get total-workouts current-stats)))
  )
    (asserts! (user-exists user) ERR-USER-NOT-FOUND)

    (map-set fitness-stats
      {user: user}
      {
        current-weight: current-weight,
        weekly-cardio-minutes: weekly-cardio-minutes,
        weekly-strength-sessions: weekly-strength-sessions,
        total-workouts: new-total-workouts,
        last-updated: current-time
      }
    )

    ;; Check if any achievements are unlocked
    (if workout-completed
      (check-achievement-milestone user)
      false
    )

    (ok true)
  )
)

;; Set workout preferences
(define-public (set-workout-preferences 
  (preferred-activities (list 10 (string-utf8 30)))
  (preferred-intensity uint)
  (preferred-duration uint)
  (preferred-time (string-utf8 20))
)
  (let (
    (user tx-sender)
  )
    (asserts! (user-exists user) ERR-USER-NOT-FOUND)
    (asserts! (<= preferred-intensity u10) ERR-INVALID-PARAMETER)

    (map-set workout-preferences
      {user: user}
      {
        preferred-activities: preferred-activities,
        preferred-intensity: preferred-intensity,
        preferred-duration: preferred-duration,
        preferred-time: preferred-time
      }
    )

    (ok true)
  )
)

;; Request connection with another user
(define-public (request-connection (connection-user principal))
  (let (
    (user tx-sender)
    (current-time (get-current-time))
  )
    (asserts! (user-exists user) ERR-USER-NOT-FOUND)
    (asserts! (user-exists connection-user) ERR-USER-NOT-FOUND)
    (asserts! (not (is-eq user connection-user)) ERR-INVALID-PARAMETER)
    (asserts! (not (connection-exists user connection-user)) ERR-CONNECTION-ALREADY-EXISTS)

    (map-set connections
      {user: user, connection: connection-user}
      {
        status: "pending",
        connected-at: current-time
      }
    )

    (ok true)
  )
)

;; Accept connection request
(define-public (accept-connection (requestor principal))
  (let (
    (user tx-sender)
    (current-time (get-current-time))
  )
    (asserts! (user-exists user) ERR-USER-NOT-FOUND)
    (asserts! (user-exists requestor) ERR-USER-NOT-FOUND)
    
    ;; Check if there's a pending request
    (asserts! (is-some (map-get? connections {user: requestor, connection: user})) ERR-CONNECTION-NOT-FOUND)
    (asserts! (is-eq (get status (default-to {status: "", connected-at: u0} 
      (map-get? connections {user: requestor, connection: user}))) "pending") ERR-CONNECTION-NOT-FOUND)

    ;; Update the connection status
    (map-set connections
      {user: requestor, connection: user}
      {
        status: "connected",
        connected-at: current-time
      }
    )

    ;; Create the reverse connection
    (map-set connections
      {user: user, connection: requestor}
      {
        status: "connected",
        connected-at: current-time
      }
    )

    (ok true)
  )
)

;; Create a fitness group
(define-public (create-fitness-group 
  (name (string-utf8 50)) 
  (description (string-utf8 500))
  (max-members uint)
  (focus-area (string-utf8 30))
  (is-public bool)
)
  (let (
    (user tx-sender)
    (current-time (get-current-time))
    (group-id (var-get next-group-id))
  )
    (asserts! (user-exists user) ERR-USER-NOT-FOUND)
    (asserts! (> (len name) u0) ERR-INVALID-PARAMETER)
    (asserts! (> max-members u0) ERR-INVALID-PARAMETER)

    ;; Create the group
    (map-set fitness-groups
      {group-id: group-id}
      {
        name: name,
        description: description,
        creator: user,
        created-at: current-time,
        max-members: max-members,
        focus-area: focus-area,
        is-public: is-public
      }
    )

    ;; Add creator as admin member
    (map-set group-members
      {group-id: group-id, user: user}
      {
        joined-at: current-time,
        role: "admin"
      }
    )

    ;; Increment group ID
    (var-set next-group-id (+ group-id u1))

    (ok group-id)
  )
)

;; Join a fitness group
(define-public (join-fitness-group (group-id uint))
  (let (
    (user tx-sender)
    (current-time (get-current-time))
    (group (unwrap! (map-get? fitness-groups {group-id: group-id}) ERR-GROUP-NOT-FOUND))
  )
    (asserts! (user-exists user) ERR-USER-NOT-FOUND)
    (asserts! (not (is-group-member group-id user)) ERR-ALREADY-GROUP-MEMBER)
    
    ;; Check if group is public
    (asserts! (get is-public group) ERR-NOT-AUTHORIZED)

    ;; Add as member
    (map-set group-members
      {group-id: group-id, user: user}
      {
        joined-at: current-time,
        role: "member"
      }
    )

    (ok true)
  )
)

;; Create a fitness challenge
(define-public (create-fitness-challenge 
  (name (string-utf8 50)) 
  (description (string-utf8 500))
  (start-date uint)
  (end-date uint)
  (challenge-type (string-utf8 30))
  (target-value uint)
  (reward-points uint)
)
  (let (
    (user tx-sender)
    (current-time (get-current-time))
    (challenge-id (var-get next-challenge-id))
  )
    (asserts! (user-exists user) ERR-USER-NOT-FOUND)
    (asserts! (> (len name) u0) ERR-INVALID-PARAMETER)
    (asserts! (>= end-date start-date) ERR-INVALID-PARAMETER)
    (asserts! (>= start-date current-time) ERR-INVALID-PARAMETER)
    (asserts! (> target-value u0) ERR-INVALID-PARAMETER)

    ;; Create the challenge
    (map-set fitness-challenges
      {challenge-id: challenge-id}
      {
        name: name,
        description: description,
        creator: user,
        start-date: start-date,
        end-date: end-date,
        challenge-type: challenge-type,
        target-value: target-value,
        reward-points: reward-points,
        is-active: true
      }
    )

    ;; Auto-join creator to the challenge
    (map-set challenge-participants
      {challenge-id: challenge-id, user: user}
      {
        joined-at: current-time,
        current-progress: u0,
        completed: false,
        completed-at: none
      }
    )

    ;; Increment challenge ID
    (var-set next-challenge-id (+ challenge-id u1))

    (ok challenge-id)
  )
)

;; Join a fitness challenge
(define-public (join-challenge (challenge-id uint))
  (let (
    (user tx-sender)
    (current-time (get-current-time))
    (challenge (unwrap! (map-get? fitness-challenges {challenge-id: challenge-id}) ERR-CHALLENGE-NOT-FOUND))
  )
    (asserts! (user-exists user) ERR-USER-NOT-FOUND)
    (asserts! (not (has-joined-challenge challenge-id user)) ERR-ALREADY-JOINED-CHALLENGE)
    (asserts! (get is-active challenge) ERR-CHALLENGE-ENDED)
    (asserts! (<= current-time (get end-date challenge)) ERR-CHALLENGE-ENDED)

    ;; Join the challenge
    (map-set challenge-participants
      {challenge-id: challenge-id, user: user}
      {
        joined-at: current-time,
        current-progress: u0,
        completed: false,
        completed-at: none
      }
    )

    (ok true)
  )
)

;; Update challenge progress
(define-public (update-challenge-progress (challenge-id uint) (progress-amount uint))
  (let (
    (user tx-sender)
    (current-time (get-current-time))
    (challenge (unwrap! (map-get? fitness-challenges {challenge-id: challenge-id}) ERR-CHALLENGE-NOT-FOUND))
    (participant (unwrap! (map-get? challenge-participants {challenge-id: challenge-id, user: user}) ERR-USER-NOT-FOUND))
    (new-progress (+ (get current-progress participant) progress-amount))
    (target-value (get target-value challenge))
    (is-now-completed (>= new-progress target-value))
  )
    (asserts! (user-exists user) ERR-USER-NOT-FOUND)
    (asserts! (has-joined-challenge challenge-id user) ERR-USER-NOT-FOUND)
    (asserts! (get is-active challenge) ERR-CHALLENGE-ENDED)
    (asserts! (<= current-time (get end-date challenge)) ERR-CHALLENGE-ENDED)
    (asserts! (not (get completed participant)) ERR-MILESTONE-INVALID)

    ;; Update progress
    (map-set challenge-participants
      {challenge-id: challenge-id, user: user}
      {
        joined-at: (get joined-at participant),
        current-progress: new-progress,
        completed: is-now-completed,
        completed-at: (if is-now-completed (some current-time) none)
      }
    )

    ;; If challenge completed, grant achievement
    (if is-now-completed
      (grant-achievement 
        user 
        (concat "Completed: " (get name challenge))
        (concat "Successfully completed the " (get name challenge) " challenge")
        (get reward-points challenge)
      )
      false
    )

    (ok is-now-completed)
  )
)

;; End a challenge (only for challenge creator)
(define-public (end-challenge (challenge-id uint))
  (let (
    (user tx-sender)
    (challenge (unwrap! (map-get? fitness-challenges {challenge-id: challenge-id}) ERR-CHALLENGE-NOT-FOUND))
  )
    (asserts! (is-eq user (get creator challenge)) ERR-NOT-AUTHORIZED)
    (asserts! (get is-active challenge) ERR-CHALLENGE-ENDED)

    ;; Update challenge status
    (map-set fitness-challenges
      {challenge-id: challenge-id}
      (merge challenge {is-active: false})
    )

    (ok true)
  )
)