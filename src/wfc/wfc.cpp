/*
This software is dual-licensed to the public domain and under the following
license: you are granted a perpetual, irrevocable license to copy, modify,
publish, and distribute this file as you see fit.
*/
#include <algorithm>
#include <array>
#include <cmath>
#include <limits>
#include <memory>
#include <numeric>
// #include <random>
#include <unordered_map>
#include <unordered_set>
#include <vector>
extern "C" {
#include "SFMT.h"
}

// #define NDEBUG 1
// #define LOGURU_IMPLEMENTATION 1
// #include "loguru.hpp"
#include "irange.hpp"

#include "arrays.hpp"

#include "lua_wfc.hpp"

using emilib::irange;

// struct RGBA
// {
// 	uint8_t r, g, b, a;
// };
// static_assert(sizeof(RGBA) == 4, "");
// bool operator==(RGBA x, RGBA y) { return x.r == y.r && x.g == y.g && x.b == y.b && x.a == y.a; }
typedef uint8_t RGBA;

using Bool              = uint8_t; // To avoid problems with vector<bool>
using ColorIndex        = uint8_t; // tile index or color index. If you have more than 255, don't.
using Palette           = std::vector<RGBA>;
using Pattern           = std::vector<ColorIndex>;
using PatternHash       = uint64_t; // Another representation of a Pattern.
using PatternPrevalence = std::unordered_map<PatternHash, size_t>;
using RandomDouble      = std::function<double()>;
using PatternIndex      = uint16_t;

const auto kInvalidIndex = static_cast<size_t>(-1);
const auto kInvalidHash = static_cast<PatternHash>(-1);

const size_t kUpscale             =   4; // Upscale images before saving

enum class Result
{
	kSuccess,
	kFail,
	kUnfinished,
};

const char* result2str(const Result result)
{
	return result == Result::kSuccess ? "success"
	     : result == Result::kFail    ? "fail"
	     : "unfinished";
}

const size_t MAX_COLORS = 1 << (sizeof(ColorIndex) * 8);

using Graphics = Array2D<std::vector<ColorIndex>>;

struct PalettedImage
{
	size_t                  width, height;
	std::vector<ColorIndex> data; // width * height
	Palette                 palette;

	ColorIndex at_wrapped(size_t x, size_t y) const
	{
		return data[width * (y % height) + (x % width)];
	}
};

// What actually changes
struct Output
{
	// _width X _height X num_patterns
	// _wave.get(x, y, t) == is the pattern t possible at x, y?
	// Starts off true everywhere.
	Array3D<Bool> _wave;
	Array2D<Bool> _changes; // _width X _height. Starts off false everywhere.
};

using Image = Array2D<RGBA>;

// ----------------------------------------------------------------------------

Image upsample(const Image& image)
{
	Image result(image.width() * kUpscale, image.height() * kUpscale, {});
	for (const auto y : irange(result.height())) {
		for (const auto x : irange(result.width())) {
			result.set(x, y, image.get(x / kUpscale, y / kUpscale));
		}
	}
	return result;
}

// ----------------------------------------------------------------------------

class Model
{
public:
	size_t              _width;      // Of output image.
	size_t              _height;     // Of output image.
	size_t              _num_patterns;
	bool                _periodic_out;
	size_t              _foundation = kInvalidIndex; // Index of pattern which is at the base, or kInvalidIndex

	// The weight of each pattern (e.g. how often that pattern occurs in the sample image).
	std::vector<double> _pattern_weight; // num_patterns

	virtual bool propagate(Output* output) const = 0;
	virtual bool on_boundary(int x, int y) const = 0;
	virtual Image image(const Output& output) const = 0;
};

// ----------------------------------------------------------------------------

class OverlappingModel : public Model
{
public:
	OverlappingModel(
		const PatternPrevalence& hashed_patterns,
		const Palette&           palette,
		int                      n,
		bool                     periodic_out,
		size_t                   width,
		size_t                   height,
		PatternHash              foundation_pattern);

	bool propagate(Output* output) const override;

	bool on_boundary(int x, int y) const override
	{
		return !_periodic_out && (x + _n > _width || y + _n > _height);
	}

	Image image(const Output& output) const override;

	Graphics graphics(const Output& output) const;

private:
	int                       _n;
	// num_patterns X (2 * n - 1) X (2 * n - 1) X ???
	// list of other pattern indices that agree on this x/y offset (?)
	Array3D<std::vector<PatternIndex>> _propagator;
	std::vector<Pattern>               _patterns;
	Palette                            _palette;
};

// ----------------------------------------------------------------------------
/*
using Tile = std::vector<RGBA>;
using TileLoader = std::function<Tile(const std::string& tile_name)>;

class TileModel : public Model
{
public:
	TileModel(const configuru::Config& config, std::string subset_name, int width, int height, bool periodic, const TileLoader& tile_loader);

	bool propagate(Output* output) const override;

	bool on_boundary(int x, int y) const override
	{
		return false;
	}

	Image image(const Output& output) const override;

private:
	Array3D<Bool>                  _propagator; // 4 X _num_patterns X _num_patterns
	std::vector<std::vector<RGBA>> _tiles;
	size_t                         _tile_size;
};
*/
// ----------------------------------------------------------------------------

double calc_sum(const std::vector<double>& a)
{
	return std::accumulate(a.begin(), a.end(), 0.0);
}

// Pick a random index weighted by a
size_t spin_the_bottle(const std::vector<double>& a, double between_zero_and_one)
{
	double sum = calc_sum(a);

	if (sum == 0.0) {
		return std::floor(between_zero_and_one * a.size());
	}

	double between_zero_and_sum = between_zero_and_one * sum;

	double accumulated = 0;

	for (auto i : irange(a.size())) {
		accumulated += a[i];
		if (between_zero_and_sum <= accumulated) {
			return i;
		}
	}

	return 0;
}

PatternHash hash_from_pattern(const Pattern& pattern, size_t palette_size)
{
	// CHECK_LT_F(std::pow((double)palette_size, (double)pattern.size()),
	//            std::pow(2.0, sizeof(PatternHash) * 8),
	//            "Too large palette (it is %lu) or too large pattern size (it's %.0f)",
	//            palette_size, std::sqrt(pattern.size()));
	PatternHash result = 0;
	size_t power = 1;
	for (const auto i : irange(pattern.size()))
	{
		result += pattern[pattern.size() - 1 - i] * power;
		power *= palette_size;
	}
	return result;
}

Pattern pattern_from_hash(const PatternHash hash, int n, size_t palette_size)
{
	size_t residue = hash;
	size_t power = std::pow(palette_size, n * n);
	Pattern result(n * n);

	for (size_t i = 0; i < result.size(); ++i)
	{
		power /= palette_size;
		size_t count = 0;

		while (residue >= power)
		{
			residue -= power;
			count++;
		}

		result[i] = static_cast<ColorIndex>(count);
	}

	return result;
}

template<typename Fun>
Pattern make_pattern(int n, const Fun& fun)
{
	Pattern result(n * n);
	for (auto dy : irange(n)) {
		for (auto dx : irange(n)) {
			result[dy * n + dx] = fun(dx, dy);
		}
	}
	return result;
};

// ----------------------------------------------------------------------------

OverlappingModel::OverlappingModel(
	const PatternPrevalence& hashed_patterns,
	const Palette&           palette,
	int                      n,
	bool                     periodic_out,
	size_t                   width,
	size_t                   height,
	PatternHash              foundation_pattern)
{
	_width        = width;
	_height       = height;
	_num_patterns = hashed_patterns.size();
	_periodic_out = periodic_out;
	_n            = n;
	_palette      = palette;

	for (const auto& it : hashed_patterns) {
		if (it.first == foundation_pattern) {
			_foundation = _patterns.size();
		}

		_patterns.push_back(pattern_from_hash(it.first, n, _palette.size()));
		_pattern_weight.push_back(it.second);
	}

	const auto agrees = [&](const Pattern& p1, const Pattern& p2, int dx, int dy) {
		int xmin = dx < 0 ? 0 : dx, xmax = dx < 0 ? dx + n : n;
		int ymin = dy < 0 ? 0 : dy, ymax = dy < 0 ? dy + n : n;
		for (int y = ymin; y < ymax; ++y) {
			for (int x = xmin; x < xmax; ++x) {
				if (p1[x + n * y] != p2[x - dx + n * (y - dy)]) {
					return false;
				}
			}
		}
		return true;
	};

	_propagator = Array3D<std::vector<PatternIndex>>(_num_patterns, 2 * n - 1, 2 * n - 1, {});

	size_t longest_propagator = 0;
	size_t sum_propagator = 0;

	for (auto t : irange(_num_patterns)) {
		for (auto x : irange<int>(2 * n - 1)) {
			for (auto y : irange<int>(2 * n - 1)) {
				auto& list = _propagator.mut_ref(t, x, y);
				for (auto t2 : irange(_num_patterns)) {
					if (agrees(_patterns[t], _patterns[t2], x - n + 1, y - n + 1)) {
						list.push_back(t2);
					}
				}
				list.shrink_to_fit();
				longest_propagator = std::max(longest_propagator, list.size());
				sum_propagator += list.size();
			}
		}
	}

	printf("[WaveFunctionCollapse] propagator length: mean/max/sum: %.1f, %lu, %lu\n", (double)sum_propagator / _propagator.size(), longest_propagator, sum_propagator);
}

bool OverlappingModel::propagate(Output* output) const
{
	bool did_change = false;

	for (int x1 = 0; x1 < _width; ++x1) {
		for (int y1 = 0; y1 < _height; ++y1) {
			if (!output->_changes.get(x1, y1)) { continue; }
			output->_changes.set(x1, y1, false);

			for (int dx = -_n + 1; dx < _n; ++dx) {
				for (int dy = -_n + 1; dy < _n; ++dy) {
					auto x2 = x1 + dx;
					auto y2 = y1 + dy;

					auto sx = x2;
					if      (sx <  0)      { sx += _width; }
					else if (sx >= _width) { sx -= _width; }

					auto sy = y2;
					if      (sy <  0)       { sy += _height; }
					else if (sy >= _height) { sy -= _height; }

					if (!_periodic_out && (sx + _n > _width || sy + _n > _height)) {
						continue;
					}

					for (int t2 = 0; t2 < _num_patterns; ++t2) {
						if (!output->_wave.get(sx, sy, t2)) { continue; }

						bool can_pattern_fit = false;

						const auto& prop = _propagator.ref(t2, _n - 1 - dx, _n - 1 - dy);
						for (const auto& t3 : prop) {
							if (output->_wave.get(x1, y1, t3)) {
								can_pattern_fit = true;
								break;
							}
						}

						if (!can_pattern_fit) {
							output->_changes.set(sx, sy, true);
							output->_wave.set(sx, sy, t2, false);
							did_change = true;
						}
					}
				}
			}
		}
	}

	return did_change;
}

Graphics OverlappingModel::graphics(const Output& output) const
{
	Graphics result(_width, _height, {});
	for (const auto y : irange(_height)) {
		for (const auto x : irange(_width)) {
			auto& tile_constributors = result.mut_ref(x, y);

			for (int dy = 0; dy < _n; ++dy) {
				for (int dx = 0; dx < _n; ++dx) {
					int sx = x - dx;
					if (sx < 0) sx += _width;

					int sy = y - dy;
					if (sy < 0) sy += _height;

					if (on_boundary(sx, sy)) { continue; }

					for (int t = 0; t < _num_patterns; ++t) {
						if (output._wave.get(sx, sy, t)) {
							tile_constributors.push_back(_patterns[t][dx + dy * _n]);
						}
					}
				}
			}
		}
	}
	return result;
}

Image image_from_graphics(const Graphics& graphics, const Palette& palette)
{
	Image result(graphics.width(), graphics.height(), 0);

	for (const auto y : irange(graphics.height())) {
		for (const auto x : irange(graphics.width())) {
			const auto& tile_constributors = graphics.ref(x, y);
			if (tile_constributors.empty()) {
				result.set(x, y, 0);
			} else if (tile_constributors.size() == 1) {
				result.set(x, y, palette[tile_constributors[0]]);
			} else {
				size_t r = 0;
				for (const auto tile : tile_constributors) {
					r += palette[tile];
				}
				r /= tile_constributors.size();
				result.set(x, y, (uint8_t)r);
			}
		}
	}

	return result;
}

Image OverlappingModel::image(const Output& output) const
{
	return image_from_graphics(graphics(output), _palette);
	// return upsample(image_from_graphics(graphics(output), _palette));
}

// ----------------------------------------------------------------------------
/* DGDGDGDG
Tile rotate(const Tile& in_tile, const size_t tile_size)
{
	CHECK_EQ_F(in_tile.size(), tile_size * tile_size);
	Tile out_tile;
	for (size_t y : irange(tile_size)) {
		for (size_t x : irange(tile_size)) {
			out_tile.push_back(in_tile[tile_size - 1 - y + x * tile_size]);
		}
	}
	return out_tile;
}

TileModel::TileModel(const configuru::Config& config, std::string subset_name, int width, int height, bool periodic_out, const TileLoader& tile_loader)
{
	_width        = width;
	_height       = height;
	_periodic_out = periodic_out;

	_tile_size        = config.get_or("tile_size", 16);
	const bool unique = config.get_or("unique",    false);

	std::unordered_set<std::string> subset;
	if (subset_name != "") {
		for (const auto& tile_name : config["subsets"][subset_name].as_array()) {
			subset.insert(tile_name.as_string());
		}
	}

	std::vector<std::array<int,     8>>  action;
	std::unordered_map<std::string, size_t> first_occurrence;

	for (const auto& tile : config["tiles"].as_array()) {
		const std::string tile_name = tile["name"].as_string();
		if (!subset.empty() && subset.count(tile_name) == 0) { continue; }

		std::function<int(int)> a, b;
		int cardinality;

		std::string sym = tile.get_or("symmetry", "X");
		if (sym == "L") {
			cardinality = 4;
			a = [](int i){ return (i + 1) % 4; };
			b = [](int i){ return i % 2 == 0 ? i + 1 : i - 1; };
		} else if (sym == "T") {
			cardinality = 4;
			a = [](int i){ return (i + 1) % 4; };
			b = [](int i){ return i % 2 == 0 ? i : 4 - i; };
		} else if (sym == "I") {
			cardinality = 2;
			a = [](int i){ return 1 - i; };
			b = [](int i){ return i; };
		} else if (sym == "\\") {
			cardinality = 2;
			a = [](int i){ return 1 - i; };
			b = [](int i){ return 1 - i; };
		} else if (sym == "X") {
			cardinality = 1;
			a = [](int i){ return i; };
			b = [](int i){ return i; };
		} else {
			ABORT_F("Unknown symmetry '%s'", sym.c_str());
		}

		const size_t num_patterns_so_far = action.size();
		first_occurrence[tile_name] = num_patterns_so_far;

		for (int t = 0; t < cardinality; ++t) {
			std::array<int, 8> map;

			map[0] = t;
			map[1] = a(t);
			map[2] = a(a(t));
			map[3] = a(a(a(t)));
			map[4] = b(t);
			map[5] = b(a(t));
			map[6] = b(a(a(t)));
			map[7] = b(a(a(a(t))));

			for (int s = 0; s < 8; ++s) {
				map[s] += num_patterns_so_far;
			}

			action.push_back(map);
		}

		if (unique) {
			for (int t = 0; t < cardinality; ++t) {
				const Tile bitmap = tile_loader(emilib::strprintf("[WaveFunctionCollapse] %s %d", tile_name.c_str(), t));
				CHECK_EQ_F(bitmap.size(), _tile_size * _tile_size);
				_tiles.push_back(bitmap);
			}
		} else {
			const Tile bitmap = tile_loader(emilib::strprintf("[WaveFunctionCollapse] %s", tile_name.c_str()));
			CHECK_EQ_F(bitmap.size(), _tile_size * _tile_size);
			_tiles.push_back(bitmap);
			for (int t = 1; t < cardinality; ++t) {
				_tiles.push_back(rotate(_tiles[num_patterns_so_far + t - 1], _tile_size));
			}
		}

		for (int t = 0; t < cardinality; ++t) {
			_pattern_weight.push_back(tile.get_or("weight", 1.0));
		}
	}

	_num_patterns = action.size();

	_propagator = Array3D<Bool>(4, _num_patterns, _num_patterns, false);

	for (const auto& neighbor : config["neighbors"].as_array()) {
		const auto left  = neighbor["left"];
		const auto right = neighbor["right"];
		CHECK_EQ_F(left.array_size(),  2u);
		CHECK_EQ_F(right.array_size(), 2u);

		const auto left_tile_name = left[0].as_string();
		const auto right_tile_name = right[0].as_string();

		if (!subset.empty() && (subset.count(left_tile_name) == 0 || subset.count(right_tile_name) == 0)) { continue; }

		int L = action[first_occurrence[left_tile_name]][left[1].get<int>()];
		int R = action[first_occurrence[right_tile_name]][right[1].get<int>()];
		int D = action[L][1];
		int U = action[R][1];

		_propagator.set(0, L,            R,            true);
		_propagator.set(0, action[L][6], action[R][6], true);
		_propagator.set(0, action[R][4], action[L][4], true);
		_propagator.set(0, action[R][2], action[L][2], true);

		_propagator.set(1, D,            U,            true);
		_propagator.set(1, action[U][6], action[D][6], true);
		_propagator.set(1, action[D][4], action[U][4], true);
		_propagator.set(1, action[U][2], action[D][2], true);
	}

	for (int t1 = 0; t1 < _num_patterns; ++t1) {
		for (int t2 = 0; t2 < _num_patterns; ++t2) {
			_propagator.set(2, t1, t2, _propagator.get(0, t2, t1));
			_propagator.set(3, t1, t2, _propagator.get(1, t2, t1));
		}
	}
}

bool TileModel::propagate(Output* output) const
{
	bool did_change = false;

	for (int x2 = 0; x2 < _width; ++x2) {
		for (int y2 = 0; y2 < _height; ++y2) {
			for (int d = 0; d < 4; ++d) {
				int x1 = x2, y1 = y2;
				if (d == 0) {
					if (x2 == 0) {
						if (!_periodic_out) { continue; }
						x1 = _width - 1;
					} else {
						x1 = x2 - 1;
					}
				} else if (d == 1) {
					if (y2 == _height - 1) {
						if (!_periodic_out) { continue; }
						y1 = 0;
					} else {
						y1 = y2 + 1;
					}
				} else if (d == 2) {
					if (x2 == _width - 1) {
						if (!_periodic_out) { continue; }
						x1 = 0;
					} else {
						x1 = x2 + 1;
					}
				} else {
					if (y2 == 0) {
						if (!_periodic_out) { continue; }
						y1 = _height - 1;
					} else {
						y1 = y2 - 1;
					}
				}

				if (!output->_changes.get(x1, y1)) { continue; }

				for (int t2 = 0; t2 < _num_patterns; ++t2) {
					if (output->_wave.get(x2, y2, t2)) {
						bool b = false;
						for (int t1 = 0; t1 < _num_patterns && !b; ++t1) {
							if (output->_wave.get(x1, y1, t1)) {
								b = _propagator.get(d, t1, t2);
							}
						}
						if (!b) {
							output->_wave.set(x2, y2, t2, false);
							output->_changes.set(x2, y2, true);
							did_change = true;
						}
					}
				}
			}
		}
	}

	return did_change;
}

Image TileModel::image(const Output& output) const
{
	Image result(_width * _tile_size, _height * _tile_size, {});

	for (int x = 0; x < _width; ++x) {
		for (int y = 0; y < _height; ++y) {
			double sum = 0;
			for (const auto t : irange(_num_patterns)) {
				if (output._wave.get(x, y, t)) {
					sum += _pattern_weight[t];
				}
			}

			for (int yt = 0; yt < _tile_size; ++yt) {
				for (int xt = 0; xt < _tile_size; ++xt) {
					if (sum == 0) {
						result.set(x * _tile_size + xt, y * _tile_size + yt, RGBA{0, 0, 0, 255});
					} else {
						double r = 0, g = 0, b = 0, a = 0;
						for (int t = 0; t < _num_patterns; ++t) {
							if (output._wave.get(x, y, t)) {
								RGBA c = _tiles[t][xt + yt * _tile_size];
								r += (double)c.r * _pattern_weight[t] / sum;
								g += (double)c.g * _pattern_weight[t] / sum;
								b += (double)c.b * _pattern_weight[t] / sum;
								a += (double)c.a * _pattern_weight[t] / sum;
							}
						}

						result.set(x * _tile_size + xt, y * _tile_size + yt,
						           RGBA{(uint8_t)r, (uint8_t)g, (uint8_t)b, (uint8_t)a});
					}
				}
			}
		}
	}

	return result;
}
*/
// ----------------------------------------------------------------------------

PalettedImage load_paletted_image(WFCOverlapping *config)
{
	// ERROR_CONTEXT("loading sample image");
	int width = config->sample_w, height = config->sample_h;

	std::vector<RGBA> palette;
	std::vector<ColorIndex> data;

	for (const auto y : irange(height)) {
	 for (const auto x : irange(width)) { // DGDGDGDG need to change order ??
		const RGBA color = config->sample[y][x];
		const auto color_idx = std::find(palette.begin(), palette.end(), color) - palette.begin();
		if (color_idx == palette.size()) {
			// CHECK_LT_F(palette.size(), MAX_COLORS, "Too many colors in image");
			palette.push_back(color);
		}
		data.push_back(color_idx);
	} }

	return PalettedImage{
		static_cast<size_t>(width),
		static_cast<size_t>(height),
		data, palette
	};
}

// n = side of the pattern, e.g. 3.
PatternPrevalence extract_patterns(
	const PalettedImage& sample, int n, bool periodic_in, size_t symmetry,
	PatternHash* out_lowest_pattern)
{
	// CHECK_LE_F(n, sample.width);
	// CHECK_LE_F(n, sample.height);

	const auto pattern_from_sample = [&](size_t x, size_t y) {
		return make_pattern(n, [&](size_t dx, size_t dy){ return sample.at_wrapped(x + dx, y + dy); });
	};
	const auto rotate  = [&](const Pattern& p){ return make_pattern(n, [&](size_t x, size_t y){ return p[n - 1 - y + x * n]; }); };
	const auto reflect = [&](const Pattern& p){ return make_pattern(n, [&](size_t x, size_t y){ return p[n - 1 - x + y * n]; }); };

	PatternPrevalence patterns;

	for (size_t y : irange(periodic_in ? sample.height : sample.height - n + 1)) {
		for (size_t x : irange(periodic_in ? sample.width : sample.width - n + 1)) {
			std::array<Pattern, 8> ps;
			ps[0] = pattern_from_sample(x, y);
			ps[1] = reflect(ps[0]);
			ps[2] = rotate(ps[0]);
			ps[3] = reflect(ps[2]);
			ps[4] = rotate(ps[2]);
			ps[5] = reflect(ps[4]);
			ps[6] = rotate(ps[4]);
			ps[7] = reflect(ps[6]);

			for (int k = 0; k < symmetry; ++k) {
				auto hash = hash_from_pattern(ps[k], sample.palette.size());
				patterns[hash] += 1;
				if (out_lowest_pattern && y == sample.height - 1) {
					*out_lowest_pattern = hash;
				}
			}
		}
	}

	return patterns;
}

Result find_lowest_entropy(const Model& model, const Output& output, RandomDouble& random_double,
                           int* argminx, int* argminy)
{
	// We actually calculate exp(entropy), i.e. the sum of the weights of the possible patterns

	double min = std::numeric_limits<double>::infinity();

	for (int x = 0; x < model._width; ++x) {
		for (int y = 0; y < model._height; ++y) {
			if (model.on_boundary(x, y)) { continue; }

			size_t num_superimposed = 0;
			double entropy = 0;

			for (int t = 0; t < model._num_patterns; ++t) {
				if (output._wave.get(x, y, t)) {
					num_superimposed += 1;
					entropy += model._pattern_weight[t];
				}
			}

			if (entropy == 0 || num_superimposed == 0) {
				return Result::kFail;
			}

			if (num_superimposed == 1) {
				continue; // Already frozen
			}

			// Add a tie-breaking bias:
			const double noise = 0.5 * random_double();
			entropy += noise;

			if (entropy < min) {
				min = entropy;
				*argminx = x;
				*argminy = y;
			}
		}
	}

	if (min == std::numeric_limits<double>::infinity()) {
		return Result::kSuccess;
	} else {
		return Result::kUnfinished;
	}
}

Result observe(const Model& model, Output* output, RandomDouble& random_double)
{
	int argminx, argminy;
	const auto result = find_lowest_entropy(model, *output, random_double, &argminx, &argminy);
	if (result != Result::kUnfinished) { return result; }

	std::vector<double> distribution(model._num_patterns);
	for (int t = 0; t < model._num_patterns; ++t) {
		distribution[t] = output->_wave.get(argminx, argminy, t) ? model._pattern_weight[t] : 0;
	}
	size_t r = spin_the_bottle(std::move(distribution), random_double());
	for (int t = 0; t < model._num_patterns; ++t) {
		output->_wave.set(argminx, argminy, t, t == r);
	}
	output->_changes.set(argminx, argminy, true);

	return Result::kUnfinished;
}

Output create_output(const Model& model)
{
	Output output;
	output._wave = Array3D<Bool>(model._width, model._height, model._num_patterns, true);
	output._changes = Array2D<Bool>(model._width, model._height, false);

	// for (int y = 0; y < model._height; y++) {for (int x = 0; x < 1; x++) {
	// 	for (int z = 0; z < model._num_patterns; z++) output._wave.set(x, y, z, false);
	// 	output._changes.set(x, y, true);
	// }}

	if (model._foundation != kInvalidIndex) {
		for (const auto x : irange(model._width)) {
			for (const auto t : irange(model._num_patterns)) {
				if (t != model._foundation) {
					output._wave.set(x, model._height - 1, t, false);
				}
			}
			output._changes.set(x, model._height - 1, true);

			for (const auto y : irange(model._height - 1)) {
				output._wave.set(x, y, model._foundation, false);
				output._changes.set(x, y, true);
			}

			while (model.propagate(&output));
		}
	}

	return output;
}

Result run(Output* output, const Model& model, size_t seed, size_t limit)
{
	// std::mt19937 gen(seed);
	// std::uniform_real_distribution<double> dis(0.0, 1.0);
	RandomDouble random_double = [&]() { return (double)genrand_real2(); };

	for (size_t l = 0; l < limit || limit == 0; ++l) {
		Result result = observe(model, output, random_double);

		if (result != Result::kUnfinished) {
			printf("[WaveFunctionCollapse] %s after %lu iterations\n", result2str(result), l);
			return result;
		}
		while (model.propagate(output));
	}

	printf("[WaveFunctionCollapse] Unfinished after %lu iterations\n", limit);
	return Result::kUnfinished;
}

bool run_and_write(WFCOverlapping *config, const Model& model)
{
	const size_t limit       = 5000;

	for (const auto attempt : irange(10)) {
		(void)attempt;
		int seed = rand();

		Output output = create_output(model);

		const auto result = run(&output, model, seed, limit);

		if (result == Result::kSuccess) {
			const auto image = model.image(output);
			for (const auto y : irange(image.height())) {
				for (const auto x : irange(image.width())) {
					config->output.data[y][x] = image.get(x, y);
				}
			}
			return true;
		}
	}
	return false;
}

std::unique_ptr<Model> make_overlapping(WFCOverlapping *config)
{
	const int    n              = config->n; // ",             3);
	const size_t out_width      = config->output.w; // ",        70);
	const size_t out_height     = config->output.h; // ",       70);
	const size_t symmetry       = config->symmetry; // ",      8);
	const bool   periodic_out   = config->periodic_out; // ", true);
	const bool   periodic_in    = config->periodic_in; // ",  true);
	const bool   has_foundation = config->has_foundation; // ",   false);

	const auto sample_image = load_paletted_image(config);
	printf("[WaveFunctionCollapse] palette size: %lu\n", sample_image.palette.size());
	PatternHash foundation = kInvalidHash;
	// const auto hashed_patterns = extract_patterns(sample_image, n, periodic_in, symmetry, nullptr);
	const auto hashed_patterns = extract_patterns(sample_image, n, periodic_in, symmetry, has_foundation ? &foundation : nullptr);
	printf("[WaveFunctionCollapse] Found %lu unique patterns in sample image\n", hashed_patterns.size());

	return std::unique_ptr<Model>{
		new OverlappingModel{hashed_patterns, sample_image.palette, n, periodic_out, out_width, out_height, foundation}
	};
}
/*
std::unique_ptr<Model> make_tiled(const std::string& image_dir, const configuru::Config& config)
{
	const std::string subdir     = config["subdir"].as_string();
	const size_t      out_width  = config.get_or("width",    48);
	const size_t      out_height = config.get_or("height",   48);
	const std::string subset     = config.get_or("subset",   std::string());
	const bool        periodic   = config.get_or("periodic", false);

	const TileLoader tile_loader = [&](const std::string& tile_name) -> Tile
	{
		const std::string path = emilib::strprintf("[WaveFunctionCollapse] %s%s/%s.bmp", image_dir.c_str(), subdir.c_str(), tile_name.c_str());
		int width, height, comp;
		RGBA* rgba = reinterpret_cast<RGBA*>(stbi_load(path.c_str(), &width, &height, &comp, 4));
		CHECK_NOTNULL_F(rgba);
		const auto num_pixels = width * height;
		Tile tile(rgba, rgba + num_pixels);
		stbi_image_free(rgba);
		return tile;
	};

	const auto root_dir = image_dir + subdir + "/";
	const auto tile_config = configuru::parse_file(root_dir + "data.cfg", configuru::CFG);
	return std::unique_ptr<Model>{
		new TileModel(tile_config, subset, out_width, out_height, periodic, tile_loader)
	};
}
*/
// void run_config_file(const Options& options, const std::string& path)
// {
// 	LOG_F(INFO, "Running all samples in %s", path.c_str());
// 	const auto samples = configuru::parse_file(path, configuru::CFG);
// 	const auto image_dir = samples["image_dir"].as_string();

// 	if (samples.count("overlapping")) {
// 		for (const auto& p : samples["overlapping"].as_object()) {
// 			LOG_SCOPE_F(INFO, "%s", p.key().c_str());
// 			const auto model = make_overlapping(image_dir, p.value());
// 			run_and_write(options, p.key(), p.value(), *model);
// 			p.value().check_dangling();
// 		}
// 	}

// 	if (samples.count("tiled")) {
// 		for (const auto& p : samples["tiled"].as_object()) {
// 			LOG_SCOPE_F(INFO, "Tiled %s", p.key().c_str());
// 			const auto model = make_tiled(image_dir, p.value());
// 			run_and_write(options, p.key(), p.value(), *model);
// 		}
// 	}
// }

bool wfc_generate_overlapping(WFCOverlapping *config) {
	const auto model = make_overlapping(config);
	return run_and_write(config, *model);
}
