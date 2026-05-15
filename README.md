# Neo Mode CustomTF 2026
This is a branch of Shaka's latest version of CustomTF, for Quake Team Fortress, made in early 2009. The purpose of **this** fork is to further develop Neo Mode (which was removed from newer versions of CustomTF/ProzacTF) and - like the repo this is forked from - get this older build to run on a modern server executable (in this case, MVDSV). This build requires a modified version of MVDSV (PQWSV) in order to speed up integration, created by Often. Additional edits and additions to PQWSV were made by Pulseczar to further support the older build.

Forked from Pulse's repository: https://github.com/Pulseczar1/Shaka-CustomTF-2009<br />

## Setting Up

### Scripts

Copy the scripts and configuration files in `Scripts` into your Quake directory. The directory structure should be preserved. After you put those files where they go, edit them to your needs and preferences.

### Progs/QuakeC Compiler

You will need to be able to compile the progs/mod QuakeC code. In general, any QuakeC compiler should be able to do this. It will also require a QuakeC preprocessor/precompiler, ran on the code, before the compiler. There are probably several QuakeC preprocessors out there that would work. I would recommend using the QuakeC preprocessor and compiler made for CustomTF. Windows binaries for these are included in this repo, but you can also find Linux copies of both over at Often's repository: <br />
https://gitlab.com/prozac-customtf/quakec-preprocessor <br />
https://gitlab.com/prozac-customtf/quakec-compiler <br />  
  
**PLEASE NOTE:** *The following instructions are specific to the above linked repos and are not guaranteed to work with other repos. This should be expected as this is not software that I actively maintain and the software could change at any time, but there are plenty of people and resources available that can help compile programs.*  
  
At the time of this writing, running `make` in the same directory as the source code is sufficient for compiling on a Linux machine. Once you get the two programs compiled, place them in the `Progs` directory. Name the preprocessor `cppreqcc` and the compiler `cpqccx`. If you are in Windows, you'll need to put `.exe` on the end of the file names.

## Compiling on Linux

### Compiling the Progs QuakeC Code

 * Set `PATH_TO_FORTRESS_DIRECTORY` in `Progs/make.sh`.  
 * Run `make.sh` in `Progs` to compile the CustomTF progs/mod code.  

### Compiling the Server Engine, PQWSV (MVDSV)

 * Set `PATH_TO_QUAKE_DIRECTORY` in `PQWSV/build/make/compile` and change the parallel job count (`-j#`) to the number of processing cores available on your machine (double it if you have hyperthreading), plus 1.  
 * Run `compile`, in `PQWSV/build/make`, to compile the PQWSV executable.  

## Compiling on Windows

### Compiling the Progs QuakeC Code

Ensure that `cppreqcc.exe` and `cpqccx.exe` already live in your `Progs` dir alongside the `.qc` files.  
Run `make.bat` to compile the CustomTF progs. Once completed, `prozac.dat` will be placed in the parent directory of the `Progs` folder.  
Place this `.dat` file in your server's `fortress` dir - example: `C:\Quake\fortress\prozac.dat`  

### Compiling the Server Engine, PQWSV (MVDSV)

**PLEASE NOTE:** *PQWSV ships with Visual Studio project files going back to VS2008 (`mvdsv_80`), up through VS2017 (`mvdsv_vc2017`). These instructions use the 2017 solution, which is the newest one included and should work fine in Visual Studio 2019 and 2022 as well.*  
  
 * Ensure Visual Studio is setup with **Desktop development with C++** workload.  
  
 * Before opening `PQWSV\build\vs\mvdsv_vc2017.vcxproj`, you may want to modify the `include` and `lib` paths within the file itself if you do not want to use the default paths.  
  
If you ***do*** want to use the default paths, simply copy the `lib` and `include` directories from `PQWSV\dependencies` to `C:\Projects\quake\mvdsv\dependencies\`  
  
If you ***DON'T*** want to use the default paths, open `PQWSV\build\vs\mvdsv_vc2017.vcxproj` in a good text editor and find all four occurrences of:
```
C:\Projects\quake\mvdsv\dependencies\include
C:\Projects\quake\mvdsv\dependencies\lib
```
and replace them with wherever you actually want to keep the files; for example:
```
G:\PQWSV\dependencies\include
G:\PQWSV\dependencies\lib
```
  
 * Open `build\vs\mvdsv_vc2017.sln` in Visual Studio and set the configuration in the toolbar (the two dropdowns at the top should read `Release-NoAsm` and `Win32`.  
  
 * Press Ctrl+Shift+B to build the binary (or click **Build > Build Solution**). The output will be `PQWSV\build\vs\qwsv.exe` - simply rename `qwsv.exe` to `pqwsv.exe`.

 * Place the `pqwsv.exe` application in your server's primary directory - usually the `Quake` dir - example: `C:\Quake\pqwsv.exe`  

## Running the server

No matter what OS you end up using, **please edit the `server.cfg` file to change the RCON PASSWORD!!**  

Suggested launch parameters: `"pqwsv.exe" -mem 96 +gamedir fortress +exec server.cfg +serverinfo neo 1 +sv_maxdownloadrate 10000000`  

### Linux
 * Copy `runNeoCuTF.sh` (Bash script) and `fortress` folder **from** this repo's `Scripts` directory **to** your Quake server directory.  
 * In your Quake server directory, execute: `./runNeoCuTF.sh public` <br />
 * Replace `public` with `test` for a private server.  

### Windows
 * Copy `runNeoCuTF.bat` (Batch file) and `fortress` folder **from** this repo's `Scripts` directory **to** your Quake server directory.
 * In your Quake server directory, run the `runNeoCuTF.bat` file. <br />

## Credits

### Neo Mode
 * Neo Mode authored by [Pulseczar](https://github.com/Pulseczar1)  
 * Idea by =Stg= Gnarler and Snake[cp]  
 * Event messages by Major Major Major Major  
 * Continued development by [STALLION / jordammit](https://github.com/jordammit/)  

### All Others
[ProzacTF by OfteN](https://gitlab.com/prozac-customtf/prozac-customtf-mod)  
[PQWSV by OfteN](https://gitlab.com/prozac-customtf/quakeworld-server)  
[CustomTF by ShakaUVM](https://github.com/ShakaUVM/CustomTF)  
All of the authors and team that builds and maintains [MVDSV](https://github.com/QW-Group/mvdsv).  
Thanks to the original team at TFSoftware for QuakeTF/Quakeworld Team Fortress.  
Thanks to the original team at id Software that created Quake.  
