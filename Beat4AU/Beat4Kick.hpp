#pragma once
#include <cmath>
#include <algorithm>

namespace beat4 {
// Stateless pitch class mapping + inexpensive stateful kick synthesizer.
// Attack transient is FIXED: only the sustained sub tail is tuned per song.
class KickVoice {
public:
    void reset() noexcept {
        age_ = 1.0; bodyPhase_ = transientPhase_ = 0;
        hp_ = previous_ = 0;
    }
    void trigger() noexcept {
        age_ = 0; bodyPhase_ = transientPhase_ = 0;
        hp_ = previous_ = 0;
    }
    double process(double sampleRate, double subHz) noexcept {
        if (age_ >= 0.75 || sampleRate <= 0 || !std::isfinite(subHz)) return 0;
        constexpr double tau = 6.283185307179586476925286766559;
        const double t = age_;
        // The fundamental follows the selected SONG note. It does not alter
        // the separately synthesized, fixed-frequency attack layer.
        bodyPhase_ += tau * subHz / sampleRate;
        if (bodyPhase_ >= tau) bodyPhase_ -= tau;
        const double bodyEnv = (1.0 - std::exp(-t / 0.0038)) * std::exp(-t / 0.223);
        const double body = std::sin(bodyPhase_) * bodyEnv;
        // Fixed analog pitch dive and snap, independent of the SONG sub note.
        const double attackHz = 67.0 + 163.0 * std::exp(-t / 0.011);
        transientPhase_ += tau * attackHz / sampleRate;
        if (transientPhase_ >= tau) transientPhase_ -= tau;
        const double attackEnv = (1.0 - std::exp(-t / 0.00085)) * std::exp(-t / 0.0155);
        const double attack = 0.46 * attackEnv * std::sin(transientPhase_);
        // Short soft punch and gentle nonlinearity produce harmonics without
        // adding a sharp, click-like sample. Final DC block protects the mix.
        const double punch = 0.07 * (std::exp(-t/0.005) - std::exp(-t/0.0015));
        const double drive = 0.70 * std::tanh((body + attack + punch) * 1.36);
        const double out = drive - previous_ + 0.9978 * hp_;
        previous_ = drive;
        hp_ = out;
        age_ += 1.0 / sampleRate;
        return out;
    }
private:
    double bodyPhase_ = 0, transientPhase_ = 0;
    double age_ = 1, hp_ = 0, previous_ = 0;
};
inline double pulseBrightness(double fraction) noexcept {
    if (!(fraction >= 0 && fraction <= 1)) return 0;
    // Phosphor: slower attack, quicker but continuous decay with zero slope
    // at both ends. A longer tail avoids an abrupt switch-off.
    if (fraction < 0.38) {
        const double x = fraction / 0.38;
        return x*x*(3.0-2.0*x);
    }
    if (fraction < 0.68) {
        const double x = (fraction-0.38)/0.30;
        const double smooth=x*x*(3.0-2.0*x);
        return 1.0-smooth;
    }
    return 0;
}
}
