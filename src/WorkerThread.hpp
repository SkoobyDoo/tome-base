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
#ifndef _WORKERTHREAD_HPP_
#define _WORKERTHREAD_HPP_

extern "C" {
#include "lua.h"
#include "types.h"
#include "lauxlib.h"
#include "lualib.h"
#include "tSDL.h"
}

#include <queue>
using namespace std;

class WorkerThread;

class WorkerTask {
private:
	SDL_mutex *lock;
	
protected:
	WorkerThread *thread = NULL;

public:
	WorkerTask();
	virtual ~WorkerTask();
	void lockData(bool lock);
	virtual void executeWorkerTask() = 0;
};

class WorkerThread {
protected:
	SDL_Thread *thread;

	SDL_mutex *lock_queue;
	SDL_sem *wait_queue;
	queue<WorkerTask*> tasks_queue;

	bool stop = false;

public:
	WorkerThread();
	virtual ~WorkerThread();

	// Run in the main thread
	void die();
	void pushTask(WorkerTask *task);
	void removeTask(WorkerThread *task);

	// Runs in the subthread
	void run();
};

#endif
