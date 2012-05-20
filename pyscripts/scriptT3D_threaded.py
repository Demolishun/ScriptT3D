#-------------------------------------------------------------------------------
# Name:        scriptT3D threaded
# Purpose:     Run scriptT3D in its own thread.
#              Example and starting point for your own threaded versions.
#              The scriptT3D_thread can be used as a basis for your own objects.
#
# Author:      Frank Carney
#
# Created:     09/05/2012
# Copyright:   (c) Frank Carney 2012
# Licence:     To be used only if you are valid licensee of the T3D engine.
#-------------------------------------------------------------------------------
#!/usr/bin/env python

import sys
import threading
from threading import Thread

# debug/utility functions

# control thread check decorators (set False for release build)
__check_script3d_thread__ = True
# check if this is the script3D_thread (method of class)
def mdec_IsScriptT3D_thread(func):
    if __check_script3d_thread__:
        def wrapper(self, *args, **kwargs):
            assert threading.current_thread().getName() == self.thread_name, "class method {0!s} called outside of {1!s} thread".format(wrapper.orig_function,self.thread_name)
            return func(self, *args, **kwargs)
        wrapper.orig_function = func
        return wrapper
    else:
        return func
# check if this is the script3D_thread (regular function)
def fdec_IsScriptT3D_thread(func, thread_name):
    if __check_script3d_thread__:
        def wrapper(*args, **kwargs):
            assert threading.current_thread().getName() == thread_name, "function {0!s} called outside of {1!s} thread".format(wrapper.orig_function,self.thread_name)
            return func(*args, **kwargs)
        wrapper.orig_function = func
        return wrapper
    else:
        return func
# check if this is NOT the script3D_thread (method of class)
def mdec_NotScriptT3D_thread(func):
    if __check_script3d_thread__:
        def wrapper(self, *args, **kwargs):
            assert threading.current_thread().getName() != self.thread_name, "class method {0!s} called inside of {1!s} thread".format(wrapper.orig_function,self.thread_name)
            return func(self, *args, **kwargs)
        wrapper.orig_function = func
        return wrapper
    else:
        return func
# check if this is NOT the script3D_thread (regular function)
def fdec_NotScriptT3D_thread(func, thread_name):
    if __check_script3d_thread__:
        def wrapper(*args, **kwargs):
            assert threading.current_thread().getName() != thread_name, "function called {0!s} inside of {1!s} thread".format(wrapper.orig_function,self.thread_name)
            return func(*args, **kwargs)
        wrapper.orig_function = func
        return wrapper
    else:
        return func



# base class for using scriptT3D in a thread
class scriptT3D_thread(Thread):
    # borg pattern for shared state
    # only allows 1 thread to be started, ever, for this class
    # http://code.activestate.com/recipes/66531/#c20
    _state = {}
    thread_name = "scriptT3D_thread"
    def __new__(cls, *p, **k):
        self = Thread.__new__(cls, *p, **k)
        self.__dict__ = cls._state
        return self
    # borg pattern for shared state

    def __init__(self, *args, **kwargs):
        Thread.__init__(self, *args, **kwargs)
        # Set thread name so that functions call tell
        #   if they are called from the proper thread.
        #   This is not necessary if you are careful
        #   where you call your functions from.
        self.setName(self.thread_name)

    # not recommended to redefine the run function
    @mdec_IsScriptT3D_thread
    def run(self):
        # must be imported here to be within the thread
        import scriptT3D

        self.engine = scriptT3D
        self.sim = self.engine.Sim()

        # init
        if not self.engine.init(len(sys.argv),sys.argv):
            return

        # call main hook
        #   This is to allow for more control of startup.
        #   If you don't want to use this then comment out this line.
        self.main_hook()

        # main loop
        while self.engine.tick():
            self.tick()

        # call for shutdown
        self.engine.shutdown()

    # threaded functions
    #   these functions are called from the thread

    # redefine if you want to change the main_hook startup
    #    This is only needed if you have an empty game.cs
    @mdec_IsScriptT3D_thread
    def main_hook(self):
        self.sim.Evaluate("""exec("main_hook.cs");""")

    # redefine to setup custom tick code
    @mdec_IsScriptT3D_thread
    def tick(self):
        pass

    # redefine to get console messages, not enabled by default
    #   use a queue to pass to other un-threaded functions/objects
    @mdec_IsScriptT3D_thread
    def console(self,level,message):
        pass

    # end threaded functions

    # un-threaded functions
    #   these functions are called from a separate thread to interface to the scriptT3D thread
    #   they use queues and other thread safe constructs to communicate to the scriptT3D thread

    # end un-threaded functions

# generic exception function
def general_exception(func):
    try:
        func()
    except (AssertionError,Exception),e:
        print e

# test program
def main():
    # This is just an example of how to use the scriptT3D thread.
    #   A lot more can be done in this part of the code.  This will
    #   run in parallel to the scriptT3D thread.  You can use
    #   queues and other thread safe communication objects to talk
    #   to the scriptT3D thread.

    # get main thread name
    # main thread default is "MainThread"
    main_thread = threading.current_thread().getName()
    print main_thread

    sthread1 = scriptT3D_thread()
    sthread2 = scriptT3D_thread()

    # start 1st thread
    general_exception(sthread1.start)
    # start 2nd thread
    # will except as all scriptT3D_thread objects share the same state
    # if thread is attempted to be started a second time it will except
    general_exception(sthread2.start)

    #sthread1.join()    # only needed if threads are run as daemons
    #sthread2.join()
    general_exception(sthread1.tick)    # thjs will cause an exception as this function is not being called from the right thread

    # this will not end the program until all non-daemon threads finish
    print "end of program: waiting for non-daemon threads"

if __name__ == '__main__':
    main()
