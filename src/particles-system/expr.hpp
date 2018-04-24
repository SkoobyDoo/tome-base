/*
    TE4 - T-Engine 4
    Copyright (C) 2009 - 2018 Nicolas Casalini

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

    Nicolas Casalini "DarkGod"
    darkgod@te4.org
*/
#ifndef _PARTICLES_EXPR_HPP
#define _PARTICLES_EXPR_HPP

using namespace std;

typedef uint32_t ExpressionID;

class Expression {
private:
	unordered_map<string, float> vars;
	vector<mu::Parser> exprs;

public:
	~Expression() {
	}

	void define(const string &name, float value) {
		vars.emplace(name, (double)value);
	}

	void finish() {
	}

	void set(const string &name, float value) {
		auto it = vars.find(name);
		if (it != vars.end()) {
			it->second = value;
		}
	}

	ExpressionID compile(const string &expr_def) {
		exprs.emplace_back();
		mu::Parser &expr = exprs.back();
		try {
			for (auto &it : vars) {
				expr.DefineVar(it.first, &it.second);
			}
			expr.SetExpr(expr_def);
		} catch (mu::Parser::exception_type &e) {
			printf("[Math Expression Parser] expression '%s' error : %s\n", expr_def.c_str(), e.GetMsg().c_str());
		}
		return exprs.size() - 1;
	}

	float eval(ExpressionID id) {
		if (id < 0 || id > exprs.size()) return 0;
		try {
			return exprs[id].Eval();
		} catch (mu::Parser::exception_type &e) {
			printf("[Math Expression Parser] expression id '%d' / '%s' error : %s\n", id, exprs[id].GetExpr().c_str(), e.GetMsg().c_str());
			return 0;
		}
	}

	void print() {
		printf("Expression system with variables:\n");
		for (auto it : vars) printf(" - %s => %f\n", it.first.c_str(), it.second);
	}
};

#endif
