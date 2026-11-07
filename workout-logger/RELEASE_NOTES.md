### Features added
- Follow a saved training program and open its next unfinished workout directly from Programs; resume an in-progress program workout without starting over.
- Connect Gemini through a separate Vertex AI Express API key, with independent provider and model choices.
- Let AI Coach and Routine Optimizer use Google Search evidence with saved source links and search suggestions.
- Opt into developer Langfuse traces in debug builds, with secure credentials, separately optional content capture, and model usage and estimated cost details.

### Fixes
- Keep completed program days linked to saved workout sessions across restarts; cancelled, empty and failed saves do not advance the plan.
- Use RepForge branding during startup and retry states, with a consistent dark native launch background.
- Correct coaching evidence dates, early/recent comparisons, independent PR maxima and uncertain load interpretation.
- Account separately for uncached, cached, output and thinking tokens using the resolved model for estimated pricing.
- Recover from search-only quota failures while retaining workout tools, and preserve fallback preferences after backup import.

### Changes
- Prioritize the followed program and next workout in Programs; keep labelled creation, import, optional AI generation, editing and export available as secondary actions.
- Make automatic model fallback an explicit saved opt-in, disabled by default; same-model retries remain available.

### Known limitations
- Program completion tracking starts with linked workouts saved by this version; older sessions are preserved without guessing which program day they completed.
- Programs follows the saved week/day order and displays prescribed weekdays; it does not automatically reschedule missed days.
- Langfuse is a developer feature in debug builds; estimated model costs are separate from provider billing.
