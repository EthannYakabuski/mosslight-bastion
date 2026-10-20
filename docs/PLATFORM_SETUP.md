# Platform setup

Godot4.5.1 Compatibility and matching templates. Android uses Java17 and the established SDK/Gradle environment. MinAPI24/targetAPI35; ARM64 and x86 debug builds. Install the Android build template before export. Android preset runnable=false prevents unrelated editor shutdown from killing ADB.

Poing AdMob and Google Play Games plugins are vendored with licenses. Google official test IDs only; Play Games enabled=false with symbolic empty IDs. Owner supplies app/backend/achievement/leaderboard IDs, consent/audience/privacy details, release signing and final production tests. Web never grants simulated native rewards.

Fullscreen modal activity is independent of reward entitlement. Simulation freezes until dismissal/failure and returns to explicit Pause; earned callback alone never resumes. Host/native services need actual root-owned QA.
