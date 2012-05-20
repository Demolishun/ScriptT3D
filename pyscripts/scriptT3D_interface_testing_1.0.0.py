#-------------------------------------------------------------------------------
# Name:        scriptT3D interface testing
# Purpose:     Testing the interface for correct operation.
#              Mainly used for development and debugging.
#              Can be used as a reference of how to use the scriptT3D extension.
#
# Author:      Frank Carney
#
# Created:     09/05/2012
# Copyright:   (c) Frank Carney 2012
# Licence:     To be used only if you are valid licensee of the T3D engine.
#-------------------------------------------------------------------------------
#!/usr/bin/env python

import sys
import scriptT3D
import sched, time
import Queue

# use for scheduling events
#   This allows us to have functions occur after a delay.
#   Good for doing tests that are created before the main loop, but execute in the main loop.
s = sched.scheduler(time.time, time.sleep)

# just assigning the object to a variable
#   Just a preference
engine = scriptT3D
# Each time you run engine.Sim() it creates an object to access the console.
#   Not a big deal, but just to help you be aware of that.  I had issues trying
#   to create a singleton.
console = engine.Sim()

# put everything in a giant exception check for testing
#   Not recommended for normal functioning.
#   I got tired of everything freezing before the engine loop...
try:

    # init
    #   Sends command line args to engine
    if not engine.init(len(sys.argv),sys.argv):
        sys.exit(1)

    # console consumer callback
    #   Sends console output to Python stdout.
    def consumerCallback(level, line):
        # notice you can tell the level # (normal, warning, error) of the message
        print level, line

    # export consumer
    engine.ExportConsumer(consumerCallback)

    # execute our own startup
    #   For my setup I rename game.cs (which is called by default) in the root directory to main_hook.cs.
    #   I create an empty game.cs so that the engine does not complain.
    #   If you prefer to use the game.cs as is then this should just give an error in the console output.
    #   My intent is to be able to more finely control the startup sequence.  Eventually I will have
    #   Python be in charge of more of the startup like creating objects and setting up the canvas.
    #   This will take some time to figure out, but in the meantime we can use the normal TS startup.
    #   Another intent is to allow pieces of the engine to be tested out.  This gives you the ability
    #   to create objects and test their interfaces without the rest of the engine getting in the way.

    # create main hook
    def main_hook():
        print "executing main_hook()"
        console.Evaluate(""" exec("main_hook.cs"); """)

    # execute the main_hook
    main_hook();

    # export a function
    def exfunction(data):
        print data
        return len(data)
    # exported into global namespace
    engine.ExportCallback(exfunction,"exfunction")
    # call using evaluate
    print console.Evaluate("""exfunction("hello");""")
    # call using execute
    #   Takes a SimObject (name or id), length of the argument list, and an argument list.
    #   If no SimObject, ie a global function, then provide empty string "".
    #   The first argument is the function name.
    #   It may make sense to make this simpler.
    arglist = ["exfunction","world"]
    print console.Execute("",len(arglist),arglist)

    # messing with global data
    console["$global_variable"] = "Some Data"
    print console.global_variable
    console.another_global = "Some more data..."
    print console["another_global"] # it is missing the $ in front, that is because the T3D function this calls assumes it is global
    print console["$another_global"] # just to show they match

    # creating a SimObject and get the id as a string
    #   It is best to let T3D create its own objects.  Hence the use of the evaluate function
    simobj = console.Evaluate("""%temp = new SimObject(UniqueObjectName){attrib1="some value";}; return %temp;""")
    print simobj # prints the id
    # use id to get a reference to a python SimObject
    psimobj = console.FindObject(simobj)
    # now print out attrib1
    print psimobj.attrib1
    # another way to get it as just providing the id or name of the SimObject will return the object, then you can get to the attrib1 value
    print console[simobj].attrib1
    # another way, if you know the object name or if you have the number, problem is you cannot put the number in from a variable easily
    print console.UniqueObjectName.attrib1
    # can set it this way too
    console.UniqueObjectName.attrib1 = "some other value"
    # make more attributes
    console.UniqueObjectName.attrib2 = "can also make new attributes"
    # get the object Torque Script equivalent
    #   Can be a way to save object states to a database...
    print repr(psimobj)

    # export a queue object
    q = Queue.Queue()
    # returns the extScriptObject created to hold the exported object
    #   Mainly useful for using in TS functions
    qobj = engine.ExportObject(q)
    # this just shows the object type
    #   Notice the unique name generated by the export.
    #   This keeps the namespace unique for each object.
    print repr(qobj)
    # get the id for use in evaluate scripts
    print qobj.getID()

    # run the main loop
    while engine.tick():
        pass

    # normal shutdown
    engine.shutdown()

except Exception,e:
    print e

