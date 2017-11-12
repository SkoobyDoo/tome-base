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

#include "WorkerThread.hpp"

/******************************************************************
 ** Task
 ******************************************************************/
WorkerTask::WorkerTask() {
	lock = SDL_CreateMutex();
}

WorkerTask::~WorkerTask() {
	SDL_DestroyMutex(lock);
}

void WorkerTask::lockData(bool l) {
	if (l) SDL_mutexP(lock);
	else SDL_mutexV(lock);
}

/******************************************************************
 ** Thread
 ******************************************************************/
static int runner(void *thread) {
	static_cast<WorkerThread*>(thread)->run();
	return 0;
}

WorkerThread::WorkerThread() {
	lock_queue = SDL_CreateMutex();
	wait_queue = SDL_CreateSemaphore(0);

	thread = SDL_CreateThread(runner, "WorkerThread", this);
}
WorkerThread::~WorkerThread() {
	SDL_DestroySemaphore(wait_queue);
	SDL_DestroyMutex(lock_queue);
}

// Run in the main thread
void WorkerThread::pushTask(WorkerTask *task) {
	SDL_mutexP(lock_queue);
	tasks_queue.push(task);
	SDL_mutexV(lock_queue);
	SDL_SemPost(wait_queue);
}

void WorkerThread::removeTask(WorkerThread *task) {
	SDL_mutexP(lock_queue);
	// DGDGDGDG: implement me
	SDL_mutexV(lock_queue);
}

void WorkerThread::die() {
	SDL_mutexP(lock_queue);
	stop = true;
	SDL_mutexV(lock_queue);
	SDL_SemPost(wait_queue);
}

// Runs in the subthread
void WorkerThread::run() {
	while (!stop)
	{
		SDL_SemWait(wait_queue);
		if (!stop) break;

		SDL_mutexP(lock_queue);
		WorkerTask *task = NULL;
		if (tasks_queue.size()) {
			task = tasks_queue.front();
			tasks_queue.pop();
		}
		SDL_mutexV(lock_queue);
		if (task) {
			task->executeWorkerTask();
		}
	}
}
