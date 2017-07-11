/*
	TE4 - T-Engine 4
	Copyright (C) 2009 - 2017 Nicolas Casalini

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
using namespace std;
using namespace glm;

enum class EventKind : uint8_t { START, EMIT, STOP, MAX };

class Event {
private:
	Ensemble *event_ensemble = nullptr;
	bool can_event = false;
	array<unique_ptr<string>, static_cast<uint8_t>(EventKind::MAX)> events_map;


public:
	void defineEvent(Ensemble *e, EventKind kind, string &name) {
		can_event = true;
		event_ensemble = e;
		events_map[static_cast<uint8_t>(kind)] = unique_ptr<string>(new string(name));
	}

	void triggerEvent(EventKind kind);
};
