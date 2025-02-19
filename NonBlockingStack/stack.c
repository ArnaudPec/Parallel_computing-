/*
 * stack.c
 *
 *  Created on: 18 Oct 2011
 *  Copyright 2011 Nicolas Melot
 *
 * This file is part of TDDD56.
 * 
 *     TDDD56 is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 * 
 *     TDDD56 is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 * 
 *     You should have received a copy of the GNU General Public License
 *     along with TDDD56. If not, see <http://www.gnu.org/licenses/>.
 * 
 */

#ifndef DEBUG
#define NDEBUG
#endif

#include <assert.h>
#include <pthread.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>

#include "stack.h"
#include "non_blocking.h"

#if NON_BLOCKING == 0



#else
#if NON_BLOCKING == 1
#warning Stacks are synchronized through hardware CAS
#else
#warning Stacks are synchronized through lock-based CAS
#endif
#endif

static int lock = 1;

void
stack_check(stack_t *stack)
{
// Do not perform any sanity check if performance is bein measured
#if MEASURE == 0
	// Use assert() to check if your stack is in a state that makes sens
	// This test should always pass 
	assert(1 == 1);

	// This test fails if the task is not allocated or if the allocation failed
	assert(stack != NULL);
#endif
}

stack_t* stack_push_aba(stack_t* head, stack_t* newHead)
{
#if NON_BLOCKING == 0
    pthread_mutex_lock(&mutex);
    newHead->ptr=head;
    pthread_mutex_unlock(&mutex);

#elif NON_BLOCKING == 1
  // Implement a harware CAS-based stack

    if(head == NULL)
    {
        newHead->ptr = head;
		printf("adds first element");
    }
    else
    {
        stack_t* old;

		printf("%i size of stack.", sizeof_stack(head));
        do
        {
            old = head;
            newHead->ptr = old;
        }while(cas(newHead->ptr, old, head) != old);
    }
    /*stack* S = newHead;*/
    
    /*stack* A = stack_pop_aba(S);*/
    /*stack_push_aba(S, A)*/
    /*pthread_mutex_unlock(&mutex);*/
#else

  // Implement a software CAS-based stack
#endif

  // Debug practice: you can check if this operation results in a stack in a consistent check
  // It doesn't harm performance as sanity check are disabled at measurement time
  // This is to be updated as your implementation progresses
  stack_check((stack_t*)1);

  return newHead;
}
stack_t* stack_push(stack_t* head, stack_t* newHead)
{
#if NON_BLOCKING == 0
    pthread_mutex_lock(&mutex);
    newHead->ptr=head;
    pthread_mutex_unlock(&mutex);

#elif NON_BLOCKING == 1
  // Implement a harware CAS-based stack

    if(head == NULL)
    {
        newHead->ptr = head;
    }
    else
    {
        stack_t* old;
        do
        {
            old = head;
            newHead->ptr = old;
        }while(cas(newHead->ptr, old, head) == old);
    }
#else

  // Implement a software CAS-based stack
#endif

  // Debug practice: you can check if this operation results in a stack in a consistent check
  // It doesn't harm performance as sanity check are disabled at measurement time
  // This is to be updated as your implementation progresses
  stack_check((stack_t*)1);

  return newHead;
}

stack_t* stack_pop_aba(stack_t* head, pthread_mutex_t* mutex, int tid)
{
    if(head == NULL)
		return NULL;
	stack_t* ret; 
#if NON_BLOCKING == 0
  // Implement a lock_based stack
    pthread_mutex_lock(&mutex);
	ret = head;
    head = head->ptr;
    pthread_mutex_unlock(&mutex);
#elif NON_BLOCKING == 1
  // Implement a harware CAS-based stack
	stack_t *newHead; 
    if (head->ptr == NULL){
        ret=head;
        head = NULL;
    }
    else
    {
        
        printf("thread %i begins pop\n", tid);
        do{
            ret = head;
            newHead = head->ptr;
            head = newHead;
            //printf("%i\n", tid);
            if(tid == 0)
            {
                //printf("%s\n", "if");
                while (lock == 1)
                {
                //printf("%s\n", "inner loop");
                }
            }
            //pthread_mutex_lock(&mutex);
        } 
        while(cas(head,newHead,newHead) ==newHead);
        printf("thread %i ends pop\n", tid);
            //pthread_mutex_unlock(&mutex);

    }
#else
  /*** Optional ***/
  // Implement a software CAS-based stack
#endif

  return ret;
}
//returns poped element
stack_t* stack_pop(stack_t* head)
{
    if(head == NULL)
		return NULL;
	stack_t* ret; 
#if NON_BLOCKING == 0
  // Implement a lock_based stack
    pthread_mutex_lock(&mutex);
	ret = head;
    head = head->ptr;
    pthread_mutex_unlock(&mutex);
#elif NON_BLOCKING == 1
  // Implement a harware CAS-based stack
	stack_t *newHead; 
    if (head->ptr == NULL){
        ret=head;
        head = NULL;
    }
    else
    {
        do{
            ret = head;
            newHead = head->ptr;
            head = newHead;
        } 
        while(cas(head,newHead,newHead)==newHead);
    }
#else
  /*** Optional ***/
  // Implement a software CAS-based stack
#endif

  return ret;
}

int sizeof_stack(stack_t* head)
{
	int i = 0;
	stack_t* temp = head;
	while(temp != NULL)
	{
		temp = temp->ptr;
		i++;
	}
	return i;
}

void unlock()
{
    lock = 0;
}
