# Stasis Coding Guidelines

* Prioritize code correctness and clarity. Speed and efficiency are secondary priorities unless otherwise specified.
* Do not write organizational or comments that summarize the code. Comments should only be written in order to explain "why" the code is written in some way in the case there is a reason that is tricky / non-obvious.
* Prefer implementing functionality in existing files unless it is a new logical component. Avoid creating many small files.
* When implementing async operations that may fail, ensure errors propagate to the UI layer so users get meaningful feedback.
* Avoid creative additions unless explicitly requested.
* Use full words for variable names (no abbreviations like "q" for "queue").

## Architecture & SMC Interactions

* Component Split: The solution is divided into the Main App (UI/Business Logic) and a Privileged Helper (System/Hardware Access).
* SMC Restriction: ALL commands dealing with the System Management Controller (SMC) must be executed within the Privileged Helper. The Main App must strictly use IPC (XPC) to request these actions.
* Library Usage: Use the `SMCKit` dependency for all SMC operations within the Helper.
    * Use `SMCKit.shared` for access.
    * Use string literal syntax for keys (e.g., `try await SMCKit.shared.read("B0TE")`).
    * Leverage `async/await` for all SMC calls; do not use legacy completion handlers.

## Swift & SwiftUI

* Safety: Avoid force unwrapping (`!`). Use optional binding (`if let`, `guard let`) or propagate errors via `throw`.
* Concurrency: Prefer Swift structured concurrency (`Task`, `async`/`await`) over GCD or completion handlers.
* UI Updates: Ensure all state changes affecting the UI are performed on the `@MainActor`.
* UI Framework: Use SwiftUI for all interface elements.
* This project targets macOS 15.7+ and Swift 6+. Concurrency features should be implemented to target and be optimized forthese platforms.
