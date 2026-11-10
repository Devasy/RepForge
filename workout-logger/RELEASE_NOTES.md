### Features added
- Find your saved routines and programs together as matching cards in Training, with your followed program first.
- Start the next unfinished workout from a program card, or resume an in-progress program workout with your logged sets intact.
- Ask Coach to build a complete program from your conversation and training history. Review the weeks, exercises, sets, reps and rest times before saving; following or switching programs is a separate choice.
- See Google Search evidence and source links in Coach and Routine Optimizer replies, with Search suggestions on live replies.
- Connect Gemini using your own Vertex AI Express key, with provider and model settings separate from Google AI Studio.
- For developers: optionally enable Langfuse traces in debug builds, with secure credentials, usage details and separately optional conversation capture.

### Fixes
- Update program progress only after a workout with logged sets is saved; deleting that workout makes its program day available again. Cancelled, empty or failed saves do not advance the plan.
- Clear the followed-program selection when that program is deleted, so recreating it does not silently follow it again.
- Improve coaching comparisons using the requested dates and actual logged sets; distinguish strength evidence from workout volume and flag missing information.
- Recover from Search quota failures while keeping workout tools available, and let users replace an unreadable Vertex key without blocking app startup or provider selection.
- Report uncached, cached, response and thinking-token usage separately when estimating model costs.

### Changes
- The Routines navigation item is now Training. Tap New to add a routine or program; each card's menu keeps details, editing and routine optimization available.
- A refreshed loading and retry screen uses the RepForge signal mark, dark theme and violet accents.
- Automatic AI model fallback is optional and off by default; retries using the selected model remain available.

### Known limitations
- Older workouts are kept, but are not retroactively assigned to program days. Completion tracking uses linked workouts saved by this version.
- Programs follow their saved week/day order; missed workouts are not automatically rescheduled.
- Saved chat history keeps answer text and source links; live Google Search suggestion chips are not saved with messages.
- Langfuse is available only in debug builds. Estimated costs are informational and separate from provider billing.
