// Lol or what ? Mingw64 on windows seems to not find it ..
#ifndef M_PI
#define M_PI                3.14159265358979323846
#endif

namespace easing {
	static float linear(float start, float end, float position) { return (end - start) * position + start; }

	static float quadraticIn(float start, float end, float position) { return (end - start) * position * position + start; }
	static float quadraticOut(float start, float end, float position) { return (-(end - start)) * position * (position - 2) + start; }
	static float quadraticInOut(float start, float end, float position) {
		position *= 2;
		if (position < 1) {
			return (((end - start) / 2) * position * position + start);
		}

		--position;
		return ((-(end - start) / 2) * (position * (position - 2) - 1) + start);
	}

	static float cubicIn (float start, float end, float position) { return ((end - start) * position * position * position + start); }
	static float cubicOut(float start, float end, float position) {
		--position;
		return ((end - start) * (position * position * position + 1) + start);
	}
	static float cubicInOut (float start, float end, float position) {
		position *= 2;
		if (position < 1) {
			return (((end - start) / 2) * position * position * position + start);
		}
		position -= 2;
		return (((end - start) / 2) * (position * position * position + 2) + start);
	}

	static float quarticIn(float start, float end, float position) { return ((end - start) * position * position * position * position + start); }
	static float quarticOut(float start, float end, float position) {
		--position;
		return ( -(end - start) * (position * position * position * position - 1) + start);
	}
	static float quarticInOut(float start, float end, float position) {
		position *= 2;
		if (position < 1) {
			return (((end - start) / 2) * (position * position * position * position) + start);
		}
		position -= 2;
		return ((-(end - start) / 2) * (position * position * position * position - 2) + start);
	}

	static float quinticIn(float start, float end, float position) { return ((end - start) * position * position * position * position * position + start); }
	static float quinticOut(float start, float end, float position) {
		position--;
		return ((end - start) * (position * position * position * position * position + 1) + start);
	}
	static float quinticInOut(float start, float end, float position) {
		position *= 2;
		if (position < 1) {
			return (
				((end - start) / 2) * (position * position * position * position * position) + start);
		}
		position -= 2;
		return (((end - start) / 2) * (position * position * position * position * position + 2) + start);
	}

	static float sinusoidalIn(float start, float end, float position) { return (-(end - start) * cosf(position * (M_PI) / 2) + (end - start) + start); }
	static float sinusoidalOut(float start, float end, float position) { return ((end - start) * sinf(position * (M_PI) / 2) + start); }
	static float sinusoidalInOut(float start, float end, float position) { return ((-(end - start) / 2) * (cosf(position * (M_PI)) - 1) + start); }

	static float exponentialIn(float start, float end, float position) { return ((end - start) * powf(2, 10 * (position - 1)) + start); }
	static float exponentialOut(float start, float end, float position) { return ((end - start) * (-powf(2, -10 * position) + 1) + start); }
	static float exponentialInOut(float start, float end, float position) {
		if (position < 1) {
			return (((end - start) / 2) * powf(2, 10 * (position - 1)) + start);
		}
		--position;
		return (((end - start) / 2) * (-powf(2, -10 * position) + 2) + start);
	}

	static float circularIn(float start, float end, float position) { return ( -(end - start) * (sqrtf(1 - position * position) - 1) + start ); }
	static float circularOut(float start, float end, float position) {
		--position;
		return ((end - start) * (sqrtf(1 - position * position)) + start);
	}
	static float circularInOut(float start, float end, float position) {
		position *= 2;
		if (position < 1) {
			return ((-(end - start) / 2) * (sqrtf(1 - position * position) - 1) + start);
		}

		position -= 2;
		return (((end - start) / 2) * (sqrtf(1 - position * position) + 1) + start);
	}

	static float bounceOut(float start, float end, float position) {
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
	static float bounceIn(float start, float end, float position) { return (end - start) - bounceOut((1 - position), 0, end) + start; }
	static float bounceInOut(float start, float end, float position) {
		if (position < 0.5f) return (bounceIn(position * 2, 0, end) * .5f + start);
		else return (bounceOut((position * 2 - 1), 0, end) * .5f + (end - start) * .5f + start);
	}

	static float elasticIn(float start, float end, float position) {
		if (position <= 0.00001f) return start;
		if (position >= 0.999f) return end;
		float p = .3f;
		float a = end - start;
		float s = p / 4;
		float postFix = a * powf(2, 10 * (position -= 1)); // this is a fix, again, with post-increment operators
		return (-(postFix * sinf((position - s) * (2 * (M_PI)) / p)) + start);
	}
	static float elasticOut(float start, float end, float position) {
		if (position <= 0.00001f) return start;
		if (position >= 0.999f) return end;
		float p = .3f;
		float a = end - start;
		float s = p / 4;
		return (a * powf(2, -10 * position) * sinf((position - s) * (2 * (M_PI)) / p) + end);
	}
	static float elasticInOut(float start, float end, float position) {
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

	static float backIn(float start, float end, float position) {
		float s = 1.70158f;
		float postFix = position;
		return ((end - start) * (postFix) * position * ((s + 1) * position - s) + start);
	}
	static float backOut(float start, float end, float position) {
		float s = 1.70158f;
		position -= 1;
		return ((end - start) * ((position) * position * ((s + 1) * position + s) + 1) + start);
	}
	static float backInOut(float start, float end, float position) {
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

static easing_ptr easings_table[] = {
	easing::linear,
	easing::quadraticIn,
	easing::quadraticOut,
	easing::quadraticInOut,
	easing::cubicIn,
	easing::cubicOut,
	easing::cubicInOut,
	easing::quarticIn,
	easing::quarticOut,
	easing::quarticInOut,
	easing::quinticIn,
	easing::quinticOut,
	easing::quinticInOut,
	easing::sinusoidalIn,
	easing::sinusoidalOut,
	easing::sinusoidalInOut,
	easing::exponentialIn,
	easing::exponentialOut,
	easing::exponentialInOut,
	easing::circularIn,
	easing::circularOut,
	easing::circularInOut,
	easing::bounceOut,
	easing::bounceIn,
	easing::bounceInOut,
	easing::elasticIn,
	easing::elasticOut,
	easing::elasticInOut,
	easing::backIn,
	easing::backOut,
	easing::backInOut,
};
