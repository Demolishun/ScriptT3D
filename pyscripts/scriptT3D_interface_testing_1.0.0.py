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

# This is an introduction to what can be done.  There may be things I have left out.
#   If you have a question as to how to do something, or need more info feel free
#   to post in the resource with your questions or suggestions.  I very much want
#   people to contribute to this codebase and have some say as to the direction it
#   takes.  I have only guessed at the usage scenarios this extension will be used
#   in.  So more input is definitely welcome.

#
#   For threading information see the scriptT3D_threaded.py file
#   For multiprocessing information see the scriptT3D_multiprocessing.py file
#   More examples will be added as time progresses.
#

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
    # show the functions and variables that got exported from the queue object
    #   This calls the 'dump' function of the SimObject.
    #   There is a lot of junk in the 'dump', but you can see the methods that got exported like: put, qsize, get
    qobj.dump()
    # testing putting something on the queue
    console.Evaluate("""{0!s}.put("{1!s}");""".format(qobj.getID(),'a message on the queue'))
    # now test pulling from the queue
    print "queue message:",q.get_nowait()

    # function callbacks
    #   These are very interesting because I had to make some decisions to get
    #   the ability to use any function as a callback, but still have the ability
    #   to detect which SimObject, if any, it was called against.  If I had not
    #   made this decision then it would be harder to export entire objects unless
    #   I used a different callback mechanism.  I finally decided to use one solid
    #   mechanism, but for every callback you can still see the SimObject if any
    #   the function was called against.  This is possible because functions are
    #   objects themselves and are capable of having attributes set on them.

    # lets create a function to test this on
    def test_callback():
        if(hasattr(test_callback,"__SimObject__")):
            print "Called from the namespace of this object:",test_callback.__SimObject__,test_callback.__SimObject__.getName()
        else:
            print "Not called from SimObject namespace"

    # now lets export some callbacks
    #   callback export syntax: ExportCallback(<function>,"name","namespace"=None,"usage"=None,override=True)
    #   function is the function or method
    #   name is the function name in TS
    #   namespace is the namespace, can be None if not used
    #   usage is the usage string, can be None if not used
    #   override is if this will override existing functions, default is True, if false it will kick back an error if override is attempted
    #   Every parameter after name is optional.
    engine.ExportCallback(test_callback,"test_callback") # global namespace
    engine.ExportCallback(test_callback,"test_callback","SimObject") # SimObject namespace
    console.Evaluate("""test_callback();""") # global call
    console.Evaluate("""{0!s}.test_callback();""".format(simobj)) # test against simobject we created earlier

    # Callbacks against class methods are the same as above.  Python class callbacks already
    #   know which Python class they are called on.  Just use the __SimObject__ attribute to find
    #   out which SimObject called the callback if any.

    # some more info on object exporting
    # complex class
    class cattrib(object):
        def __init__(self):
            self.attr1 = ['a','b']
            self.attr2 = (0,1)
            self.attr3 = {'one':1,'two':2}
            self.attr4 = int(5)
            self.attr5 = float(1.2)
            self.attr6 = str('doodle')
    # export an instance of the cattrib object
    cobj = engine.ExportObject(cattrib())
    # use id to call functions in TS
    # accessing arrays, tuples, dictionaries, stings, and numbers are supported
    #   When setting attributes from TS the functions try and maintain data if
    #   the attribute already exists.  If not it will default to a type like string
    #   or dictionary as they are easist to convert to a Python representation.
    #   So if you want a particular datatype then define it on the Python side first.
    #   Also note that if the key or index for a sequence (array, tuple, dictionary)
    #   is of the wrong type it will fail to set or read the sequence.  Tuples and strings
    #   are not able to be written as they are immutable types.
    console.Evaluate("""echo({0!s}.attr1[1]);""".format(cobj.getId()))
    console.Evaluate("""echo({0!s}.attr2[0]);""".format(cobj.getId()))
    console.Evaluate("""echo({0!s}.attr3["two"]);""".format(cobj.getId()))
    console.Evaluate("""echo({0!s}.attr4);""".format(cobj.getId()))
    console.Evaluate("""echo({0!s}.attr5);""".format(cobj.getId()))
    console.Evaluate("""echo({0!s}.attr6);""".format(cobj.getId()))

    # hwnd handle
    #   This is so other apps can use the T3D hwnd handle.  I have tested this with
    #   wxPython and it does work.  However, wxPython event system interferes with the
    #   T3D event system so it is not recommended to be used with wxPython.  Other
    #   packages I would try to use this with is pyOgre and pyGame.  Those have independent
    #   event systems that are not needed.  Now, these graphicssystems are not necessarily
    #   any better than T3D, it is I just wanted to have the capability.  There are other
    #   GUI systems that might make sense to use with T3D.
    hwnd = engine.gethwnd()

    # run the main loop
    while engine.tick():
        pass

    # normal shutdown
    engine.shutdown()

except Exception,e:
    print e

