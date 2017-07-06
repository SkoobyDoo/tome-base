// Lol or what ? Mingw64 on windows seems to not find it ..
#ifndef M_PI
#define M_PI                3.14159265358979323846
#endif

namespace easing {
	static inline float linear(float start, float end, float position) { return (end - start) * position + start; }

	static inline float quadraticIn(float start, float end, float position) { return (end - start) * position * position + start; }
	static inline float quadraticOut(float start, float end, float position) { return (-(end - start)) * position * (position - 2) + start; }
	static inline float quadraticInOut(float start, float end, float position) {
		position *= 2;
		if (position < 1) {
			return (((end - start) / 2) * position * position + start);
		}

		--position;
		return ((-(end - start) / 2) * (position * (position - 2) - 1) + start);
	}

	static inline float cubicIn (float start, float end, float position) { return ((end - start) * position * position * position + start); }
	static inline float cubicOut(float start, float end, float position) {
		--position;
		return ((end - start) * (position * position * position + 1) + start);
	}
	static inline float cubicInOut (float start, float end, float position) {
		position *= 2;
		if (position < 1) {
			return (((end - start) / 2) * position * position * position + start);
		}
		position -= 2;
		return (((end - start) / 2) * (position * position * position + 2) + start);
	}

	static inline float quarticIn(float start, float end, float position) { return ((end - start) * position * position * position * position + start); }
	static inline float quarticOut(float start, float end, float position) {
		--position;
		return ( -(end - start) * (position * position * position * position - 1) + start);
	}
	static inline float quarticInOut(float start, float end, float position) {
		position *= 2;
		if (position < 1) {
			return (((end - start) / 2) * (position * position * position * position) + start);
		}
		position -= 2;
		return ((-(end - start) / 2) * (position * position * position * position - 2) + start);
	}

	static inline float quinticIn(float start, float end, float position) { return ((end - start) * position * position * position * position * position + start); }
	static inline float quinticOut(float start, float end, float position) {
		position--;
		return ((end - start) * (position * position * position * position * position + 1) + start);
	}
	static inline float quinticInOut(float start, float end, float position) {
		position *= 2;
		if (position < 1) {
			return (
				((end - start) / 2) * (position * position * position * position * position) + start);
		}
		position -= 2;
		return (((end - start) / 2) * (position * position * position * position * position + 2) + start);
	}

	static inline float sinusoidalIn(float start, float end, float position) { return (-(end - start) * cosf(position * (M_PI) / 2) + (end - start) + start); }
	static inline float sinusoidalOut(float start, float end, float position) { return ((end - start) * sinf(position * (M_PI) / 2) + start); }
	static inline float sinusoidalInOut(float start, float end, float position) { return ((-(end - start) / 2) * (cosf(position * (M_PI)) - 1) + start); }

	static inline float exponentialIn(float start, float end, float position) { return ((end - start) * powf(2, 10 * (position - 1)) + start); }
	static inline float exponentialOut(float start, float end, float position) { return ((end - start) * (-powf(2, -10 * position) + 1) + start); }
	static inline float exponentialInOut(float start, float end, float position) {
		if (position < 1) {
			return (((end - start) / 2) * powf(2, 10 * (position - 1)) + start);
		}
		--position;
		return (((end - start) / 2) * (-powf(2, -10 * position) + 2) + start);
	}

	static inline float circularIn(float start, float end, float position) { return ( -(end - start) * (sqrtf(1 - position * position) - 1) + start ); }
	static inline float circularOut(float start, float end, float position) {
		--position;
		return ((end - start) * (sqrtf(1 - position * position)) + start);
	}
	static inline float circularInOut(float start, float end, float position) {
		position *= 2;
		if (position < 1) {
			return ((-(end - start) / 2) * (sqrtf(1 - position * position) - 1) + start);
		}

		position -= 2;
		return (((end - start) / 2) * (sqrtf(1 - position * position) + 1) + start);
	}

	static inline float bounceOut(float start, float end, float position) {
		float c = end - start;
		if (position < (1 / 2.75f)) {
			return (c * (7.5625f * position * position) + start);
		} else if (position < (2.0f / 2.75f)) {
			float postFix = position -= (1.5f / 2.75f);
			return (c * (7.5625f * (postFix) * position + .75f) + start);
		} else if (position < (2.5f / 2.75f)) {
			float postFix = position -= (2.25f / 2.75f);
			return (c * (7.5625f * (postFix) * position + .9375f) + start);
		} else {
			float postFix = position -= (2.625f / 2.75f);
			return (c * (7.5625f * (postFix) * position + .984375f) + start);
		}
	}
	static inline float bounceIn(float start, float end, float position) { return (end - start) - bounceOut((1 - position), 0, end) + start; }
	static inline float bounceInOut(float start, float end, float position) {
		if (position < 0.5f) return (bounceIn(position * 2, 0, end) * .5f + start);
		else return (bounceOut((position * 2 - 1), 0, end) * .5f + (end - start) * .5f + start);
	}

	static inline float elasticIn(float start, float end, float position) {
		if (position <= 0.00001f) return start;
		if (position >= 0.999f) return end;
		float p = .3f;
		float a = end - start;
		float s = p / 4;
		float postFix = a * powf(2, 10 * (position -= 1)); // this is a fix, again, with post-increment operators
		return (-(postFix * sinf((position - s) * (2 * (M_PI)) / p)) + start);
	}
	static inline float elasticOut(float start, float end, float position) {
		if (position <= 0.00001f) return start;
		if (position >= 0.999f) return end;
		float p = .3f;
		float a = end - start;
		float s = p / 4;
		return (a * powf(2, -10 * position) * sinf((position - s) * (2 * (M_PI)) / p) + end);
	}
	static inline float elasticInOut(float start, float end, float position) {
		if (position <= 0.00001f) return start;
		if (position >= 0.999f) return end;
		position *= 2;
		float p = (.3f * 1.5f);
		float a = end - start;
		float s = p / 4;
		float postFix;

		if (position < 1) {
			postFix = a * powf(2, 10 * (position -= 1)); // postIncrement is evil
			return (-0.5f * (postFix * sinf((position - s) * (2 * (M_PI)) / p)) + start);
		}
		postFix = a * powf(2, -10 * (position -= 1)); // postIncrement is evil
		return (postFix * sinf((position - s) * (2 * (M_PI)) / p) * .5f + end);
	}

	static inline float backIn(float start, float end, float position) {
		float s = 1.70158f;
		float postFix = position;
		return ((end - start) * (postFix) * position * ((s + 1) * position - s) + start);
	}
	static inline float backOut(float start, float end, float position) {
		float s = 1.70158f;
		position -= 1;
		return ((end - start) * ((position) * position * ((s + 1) * position + s) + 1) + start);
	}
	static inline float backInOut(float start, float end, float position) {
		float s = 1.70158f;
		float t = position;
		float b = start;
		float c = end - start;
		float d = 1;
		s *= (1.525f);
		if ((t /= d / 2) < 1) return (c / 2 * (t * t * (((s) + 1) * t - s)) + b);
		float postFix = t -= 2;
		return (c / 2 * ((postFix) * t * (((s) + 1) * t + s) + 2) + b);
	}
}
