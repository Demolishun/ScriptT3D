ScriptT3D 
Version 1.2
First MIT License Release!

Details:

This code extends Python 2.7.x with T3D.  It is about as fast as the interface 
can get without directly mapping every console function and/or function to a Python
method.  It also can handle calling any console method either compiled or dynamic.

All the methods and attribute access from Python to T3D employ exceptions.  Callbacks 
(console to Python calls) do not employ exceptions.  If a function is called from 
the console it just spits out warning or error messages.  This is mainly due to keep
consistent with how the console operates.  It also may be difficult to wrap a console
call from the Python side to catch the exceptions.  One exception to the Python side
triggering exceptions on attribute access it when accessing arrays on SimObjects.  
Due to language limitations and the lack of being able to check if an attribute of a
SimObject is an array or not.  

There is a thin Python wrapper for SimObjects.  This is designed to make attribute
access to SimObjects transparent.  If you want to change how this is done then study
the classes that wrap the methods provided with the ScriptT3D interface and either modify 
or create new wrappers of your own.  Not going through the wrappers may help speed up 
critical sections of code if necessary.  However, the wrappers are designed to take the 
guess work out of the interface, and keep the programmer out of trouble.  So YMMV. :)

Why write this interface?

My hope is that this code will give people access to the huge codebase around Python.
There are thousands of professionally designed libraries available for Python and its 
variants.  The main reason for using this interface is to reduce develop costs for non
speed critical code.  Even so there are libraries written in C for Python that are 
extremely fast at what they do.  One such example is lxml.  This library wraps some high
quality XML/XSL libraries and are extremely high performance.  Another high performance
library is PyOpenCL.  

Obviously you can take the time to interface these libraries by hand to the C++ core of 
T3D.  However, the key is taking the time to do this.  Developers don't have time to code 
forever.  Especially independent developers.  Python is known as the ultimate glue language.  
You can literally find anything needed to complete a project. Having used Python to write 
code for customers I am always amazed to find new and exciting ways I can use Python.  Python
is almost an addiction.  Once you start you can't quit!

Where am I going next with this interface?
- Binary data access from Python to T3D for certain types of data.  Sounds, textures, meshes, etc.
- Database storage of objects with functions that will build the objects for use in the T3D engine.
- Network libraries for various tasks including authorizing against OpenAuth accounts.  Mainly non
time critical network traffic.
- and more...

What do I want from the end user?
- To make awesome games that make the world a better place.
- I am hoping other users will make contributions to this interface as they solve their own unique
problems, but it is not a requirement.  I fully understand that many commercial entities cannot
do this.  That is why this is using the MIT license.  
- If I helped make your life better then I am successful.

Contact:
If you need help or want me to do consulting/programming work contact me at me@demolishun.com.