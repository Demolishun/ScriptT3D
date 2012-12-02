#-------------------------------------------------------------------------------
# Name:        Unit Testing ScriptT3D
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

import sys
import sched, time
import scriptT3D
import unittest
import ast

from colorama import Fore as cr_Fore, Back as cr_Back, Style as cr_Style
from colorama import init as cr_init, AnsiToWin32 as cr_AnsiToWin32
cr_init(autoreset=True)  # resets color changes at end of statement

# create scheduler object to call functions after engine.tick loop has started
s = sched.scheduler(time.time, time.sleep)

# console output callback
# messages of console are colored here
def consoleConsumerCallback(level, data):
    if level == 0:
        print "{0}{1}{2}".format(cr_Fore.BLUE, cr_Style.BRIGHT, data)
    elif level == 1:
        print "{0}{1}{2}".format(cr_Fore.CYAN, cr_Style.BRIGHT, data)
    elif level == 2:
        print "{0}{1}{2}".format(cr_Fore.RED, cr_Style.BRIGHT, data)

# just redefining some names to make it easier to read
engine = scriptT3D
Con = engine.Con
Globals = engine.Globals
SimObjects = engine.SimObjects

# export console output callback
engine.ExportConsumer(consoleConsumerCallback)

# define unit tests
class GlobalsConTests(unittest.TestCase):
    # tests
    def testa_GlobalsAttribException(self):
        with self.assertRaises(AttributeError):
            val = Globals.badGlobal

    def testb_GlobalsAttrib(self):
        Globals.goodGlobal1 = 10
        self.assertEqual(Globals.goodGlobal1, "10")
        Globals.goodGlobal2 = "text"
        self.assertEqual(Globals.goodGlobal2, "text")

    def testc_ConAttribException(self):
        with self.assertRaises(AttributeError):
            val = Con.badConFunction()

    def testd_ConAttrib(self):
        # this tests the initial creation of the lambda
        val = Con.eval('return "10";')
        self.assertEqual(val, "10")
        # this tests the usage of the same lambda
        val = Con.eval('return "10";')
        self.assertEqual(val, "10")

class SimObjectTests(unittest.TestCase):
    # setup for each test
    def setUp(self):
        # create a new SimObject for each test
        self.simobject = engine.evaluate('return new SimObject(TestSimObject);')
    # cleanup for each test
    def tearDown(self):
        # delete SimObject after each test
        if self.simobject is not None:
            engine.evaluate('{0}.delete();'.format(self.simobject))
            self.simobject = None

    # tests
    def testa_SimObjectsAccessByID(self):
        obj = SimObjects[self.simobject]
        objId = obj.getId()
        self.assertEqual(self.simobject, objId)
        #self.assertTrue(self.simobject == objId)

    def testa_SimObjectsAccessByName(self):
        obj = SimObjects.TestSimObject
        objId = obj.getId()
        self.assertEqual(self.simobject, objId)
        #self.assertTrue(self.simobject == objId)

    def testa_SimObjectsAttribException(self):
        with self.assertRaises(AttributeError):
            obj = SimObjects.badObject

    def testa_SimObjectsKeyException(self):
        with self.assertRaises(KeyError):
            obj = SimObjects["badObject"]
        obj = SimObjects.TestSimObject
        objId = obj.getId()
        with self.assertRaises(KeyError):
            obj = SimObjects[int(objId)+100]

    def testb_SimObjectAttribException(self):
        obj = SimObjects.TestSimObject
        with self.assertRaises(AttributeError):
            val = str(obj.badAttrib)

    def testb_SimObjectDeletedObjectException(self):
        obj = SimObjects.TestSimObject
        obj.delete()
        with self.assertRaises(RuntimeError):
            val = obj.getName()

        # prevent error on tear down
        self.simobject = None

    def testb_SimObjectAttrib(self):
        obj = SimObjects.TestSimObject
        obj.attrib1 = 10
        self.assertEqual(obj.attrib1,str(10))
        obj.attrib2 = "text"
        self.assertEqual(obj.attrib2,"text")
        obj.attrib3[0] = "more text"
        self.assertEqual(obj.attrib3[0],"more text")
        obj.attrib3[1] = "even more text"
        self.assertEqual(obj.attrib3[1],"even more text")
        self.assertEqual(obj.attrib3[2],"")
        self.assertNotEqual(obj.attrib3[3],"more text")

# test callbacks
def testCallback(data):
    obj = None
    if hasattr(testCallback, "__SimObject__"):
        obj = str(testCallback.__SimObject__)

    return (obj, data)

class testObject(object):
    def testClassCallback(self, data):
        obj = None
        if hasattr(self.testClassCallback.__func__, "__SimObject__"):
            obj = str(self.testClassCallback.__func__.__SimObject__)

        return (obj, data)

def unboundCallback(*args):
    obj = None
    if hasattr(unboundCallback, "__SimObject__"):
        obj = str(unboundCallback.__SimObject__)

    # grab last value as data from args when called as object method
    data = args[len(args)-1]
    return (obj, data)

testObject.unboundCallback = unboundCallback

def doCallbackExport():
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

    return tObj

class CallbackTests(unittest.TestCase):
    def testa_CallbackFunction(self):
        obj, data = ast.literal_eval(Con.eval('testCallback("text");'))
        self.assertEqual(obj, None)
        self.assertEqual(data, "text")

    def testa_CallbackMethod(self):
        obj, data = ast.literal_eval(Con.eval('testObject.testCallback("text");'))
        self.assertEqual(obj, str(engine.getSimObject("testObject")))
        self.assertEqual(data, "text")

    def testb_CallbackClassFunction(self):
        obj, data = ast.literal_eval(Con.eval('testClassCallback("text");'))
        self.assertEqual(obj, None)
        self.assertEqual(data, "text")

    def testb_CallbackClassMethod(self):
        obj, data = ast.literal_eval(Con.eval('testObject.testClassCallback("text");'))
        self.assertEqual(obj, str(engine.getSimObject("testObject")))
        self.assertEqual(data, "text")

    def testc_CallbackUnboundFunction(self):
        obj, data = ast.literal_eval(Con.eval('unboundCallback("text");'))
        self.assertEqual(obj, None)
        self.assertEqual(data, "text")

    def testc_CallbackUnboundMethod(self):
        obj, data = ast.literal_eval(Con.eval('testObject.unboundCallback("text");'))
        self.assertEqual(obj, str(engine.getSimObject("testObject")))
        self.assertEqual(data, "text")

def unitTests():
    print
    print "Starting Unit Tests"
    print

    # run unit tests here
    suite = unittest.TestLoader().loadTestsFromTestCase(GlobalsConTests)
    unittest.TextTestRunner(verbosity=2).run(suite)

    print

    suite = unittest.TestLoader().loadTestsFromTestCase(SimObjectTests)
    unittest.TextTestRunner(verbosity=2).run(suite)

    print

    # util functions
    # hold onto tObj ref so it doesn't get garbage collected during testing
    tObj = doCallbackExport()

    print

    suite = unittest.TestLoader().loadTestsFromTestCase(CallbackTests)
    unittest.TextTestRunner(verbosity=2).run(suite)

    print
    print "Finished Unit Tests"

# schedule unit tests
s.enter(0, 1, unitTests, ())

def main():
    # init the engine
    if not engine.init(len(sys.argv),sys.argv):
        sys.exit(1)

    # engine loop
    while engine.tick():
        s.run()

    # clean up
    engine.shutdown()

if __name__ == '__main__':
    main()
