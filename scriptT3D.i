/*
//-----------------------------------------------------------------------------
// scriptT3D
// Copyright Demolishun Consulting (Frank Carney) 2012
//-----------------------------------------------------------------------------
*/
/* File: scriptT3D.i */

/*
SWIG processing in VC++:
- Create an external tool under Tools->External Tools...
- Call the tool SWIG and point to your swig.exe executable for the 'Command'.
- Add the following Arguments: -c++ -python $(ItemPath)
- Deselect Prompt on Arguments (optional)
- Select Use Output Window (optional)
- Make scriptT3D.i the current document and select the tool from Tools->SWIG
This will build the scriptT3D_wrap.cxx and the scriptT3D.py files.
*/

/*
Custom build step for copying scriptT3D.py to game folder of project.  
This will always copy latest scriptT3D.py file to game directory every time a Build is performed.
Command Line: copy /V/Y "$(InputPath)" "$(TargetDir)"
Desciption: Copying "$(InputPath)" to game directory "$(TargetDir)"
Outputs: "$(InputDir)bogus.txt"
Additional Dependencies:
*/

/*
Callback Exporting:
If is called as a method of a TS object then function will require a 'this' parameter.
*/

%module scriptT3D

%{
#define SWIG_FILE_WITH_INIT
#include "scriptT3D.h"
%}

// default typemaps
%typemap(in) S32 = int;
%typemap(out) S32 = int;
%typemap(in) U32 = unsigned int;
%typemap(out) U32 = unsigned int;

// include python related SWIG file
#ifdef SWIGPYTHON
%include "pyT3D.i"
#endif 

%rename("%(strip:[torque_engine])s") "";
// engine startup/shutdown
int torque_engineinit(S32 argc, const char **argv);

// engine loop
int torque_enginetick();

// engine state/events
int torque_engineshutdown();

%rename("%(strip:[torque_])s") "";
// util
bool torque_isdebugbuild();

// render context
%{
long gethwnd(){
	return (long)torque_gethwnd();
}
%}
long gethwnd();
