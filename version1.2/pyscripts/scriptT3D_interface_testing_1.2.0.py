#-------------------------------------------------------------------------------
# Name:        scriptT3D interface testing
# Purpose:     Testing the interface for correct operation.
#              Mainly used for development and debugging.
#              Can be used as a reference of how to use the scriptT3D extension.
#
"""
Copyright (c) 2012 Frank Carney

Permission is hereby granted, free of charge, to any person obtaining a copy of this
software and associated documentation files (the "Software"), to deal in the Software
without restriction, including without limitation the rights to use, copy, modify,
merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to the following
conditions:
The above copyright notice and this permission notice shall be included in all copies
or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE
OR OTHER DEALINGS IN THE SOFTWARE.
"""
#-------------------------------------------------------------------------------
#!/usr/bin/env python

# This is an introduction to what can be done.  There may be things I have left out.
#   If you have a question as to how to do something, or need more info feel free
#   to post in the resource with your questions or suggestions.  I very much want
#   people to contribute to this codebase and have some say as to the direction it
#   takes.  I have only guessed at the usage scenarios this extension will be used
#   in.  So more input is definitely welcome.

import sys
import sched, time
import scriptT3D

from colorama import Fore as cr_Fore, Back as cr_Back, Style as cr_Style
from colorama import init as cr_init, AnsiToWin32 as cr_AnsiToWin32
#cr_init(wrap=False) # only for problems
#cr_stream = cr_AnsiToWin32(sys.stderr).stream # only for problems
cr_init(autoreset=True)  # resets color changes at end of statement

s = sched.scheduler(time.time, time.sleep)

engine = scriptT3D

print dir(engine)
#print dir(engine.Con)
Con = engine.Con
Globals = engine.Globals
SimObjects = engine.SimObjects

#sys.exit(0)

if not engine.init(len(sys.argv),sys.argv):
    sys.exit(1)

#execName = Con.getExecutableName()
#print "Starting up {0}...".format(execName)

# messages of console are colored here
# change to your hearts desire
def consoleConsumerCallback(level, data):
    if level == 0:
        print "{0}{1}{2}".format(cr_Fore.BLUE, cr_Style.BRIGHT, data)
    elif level == 1:
        print "{0}{1}{2}".format(cr_Fore.CYAN, cr_Style.BRIGHT, data)
    elif level == 2:
        print "{0}{1}{2}".format(cr_Fore.RED, cr_Style.BRIGHT, data)

# test callbacks
def testCallback(data, data2=None):
    if hasattr(testCallback, "__SimObject__"):
        print testCallback.__SimObject__
    if data2 is None:
        print data
    else:
        print data2

class testObject(object):
    def testClassCallback(self, data):
        if hasattr(self.testClassCallback.__func__, "__SimObject__"):
            print self.testClassCallback.__func__.__SimObject__
        print data

testObject.unboundCallback = testCallback

engine.ExportConsumer(consoleConsumerCallback)

csfile = "main_hook.cs"
#print "Executing {0}...",format(csfile)
#print Con.Exec
#Con.Exec(csfile)  # for some reason Python does not like some objects having an "exec" method
# Con.exec()   # uncomment this line to see what I am talking about
print dir(engine)

#("{0}".format(csfile))

def testfunction():
    try:
        #Con.test()
        engine.evaluate('function test(){echo("test code");}')
        Con.test()
        engine.evaluate('function test2(){echo("new test2 code");}')
        engine.evaluate('function test(){echo("new test code");}')
        Con.test2()
        Con.test()

        engine.evaluate('$Global1 = "test global1";');
        print "Global1 data:",Globals.Global1
        Globals.Global2 = "test global2"
        print "Global2 data:",Globals.Global2

        print engine.getSimObject("MyTestObject")
        evalString = \
        """
        %obj = new SimObject(MyTestObject){
            attrib1 = "attrib1";
        };
        %obj.attrib2[0] = "array1 val0";
        %obj.attrib2[1] = "array1 val1";
        return %obj;
        """
        objid = int(engine.evaluate(evalString))
        print objid

        # for some reason printing a reference to a simobject will crash, so wrap it in str()
        print str(engine.getSimObject("MyTestObject"))
        print str(engine.getSimObject(objid))
        print dir(engine.getSimObject(objid))
        print engine.getSimObjectScript(engine.getSimObject(objid))


        print "Printing Object:", SimObjects.MyTestObject

        print "by ID", SimObjects[objid]  # can be int or string that translates to name or int
        try:
            print "by bad ID", SimObjects[objid+100]
        except KeyError, e:
            print type(e), e.message


        obj = SimObjects.MyTestObject
        print obj
        obj.dump()
        print obj.getName()
        print obj.getClassName()

        print obj.canSave
        #obj.testvalue = 14 # doesn't like non string types
        obj.testvalue = "14"
        print obj.testvalue

        # testing attribute access
        print obj.attrib1
        print obj.attrib20
        print obj.attrib21
        obj.attrib3[0] = "hello"
        print "getting value 0 from array attribute:", obj.attrib3[0]
        print "getting value 1 from array attribute:", obj.attrib3[1]

        try:
            print obj.attrib3
        except Exception, e:
            print type(e), e.message
            print "cannot access attrib3 as attribute"

        try:
            print "access 1"
            obj.attrib3
            print "access 2"
            data = obj.attrib3
            print repr(data)
            print data
        except Exception, e:
            print type(e), e.message
            print "cannot access object at all?"

        print engine.getSimObjectScript(engine.getSimObject(objid))

        SimObjects.MyTestObject.delete()
        #obj.dump()
        #print obj.simobject
        #obj.hello()
        """
        """

        # example out messages to show coloring of console output
        print
        print
        print "Regular Python print output."
        Con.eval('echo("Normal message coloring.");')
        Con.eval('warn("Warning message coloring!");')
        Con.eval('error("!!!Error message coloring!!!");')
        print
        print

        # callback tests
        # ExportCallback(func,name,ns,usage,overrides=(true/false))
        tObj = testObject()

        engine.ExportCallback(testCallback,"testCallback")
        engine.ExportCallback(testCallback,"testCallback","SimObject")

        engine.ExportCallback(tObj.testClassCallback,"testClassCallback")
        engine.ExportCallback(tObj.testClassCallback,"testClassCallback","SimObject")

        # this works fine
        engine.ExportCallback(tObj.unboundCallback,"unboundCallback")
        engine.ExportCallback(tObj.unboundCallback,"unboundCallback","SimObject")

        Con.eval('new SimObject(testObject);')

        # non class function
        Con.eval('testCallback("blah");')
        Con.eval('testObject.testCallback("blah blah");')
        # class function
        Con.eval('testClassCallback("class blah");')
        Con.eval('testObject.testClassCallback("class blah blah");')
        # unbound class function
        Con.eval('unboundCallback("unbound blah");')
        Con.eval('testObject.unboundCallback("unbound blah blah");')

        #engine.shutdown()
        #exit(0)

    except Exception, e:
        print type(e), e.message
        engine.shutdown()
        exit(1)


s.enter(0, 1, testfunction, ())

while engine.tick():
    s.run()

engine.shutdown()

