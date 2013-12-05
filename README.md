vissim-tools
============
A collection of tools to be used with Vissim

All tools released under GPLv2
 
api.pl - Axle passage interpreter
apiformat.pl - Axle passage formatter
expexcel.pl - Export data to MS Excel and display a chart
resformat.pl - Printers number of vehicle passing each second
restid.pl - Prints statistics from SAVA output (video analysis)
visperl.pl - Start/load/modify/run/save vissim simulations and save results
ttstat.pl - Travel time statistics
spool.pl - Simple queue system to run a batch of vissim simulations
ec1run.pl - Run EC1 traffic simulator with given settings

api.pl
------
NAME
       api - axle passage interpreter

SYNOPSIS
       api.pl [--start=HH:MM] [--end=HH:MM] [--tubedistance=meters]
       [--maxspeed=km/h] [--minspeed=km/h] [--minaxllen=meters]
       [--maxaxllen=meters] [--maxspeedvariation=percent]
       [--bouncereject=seconds] [--careful=integer] [--debug] [--export]
       [filename..]

DESCRIPTION
       api.pl is a axle passage interpreter program designed to be used to
       analyse traffic data from pneumatic tubes and convert to axle passages.

OPTIONS
       --start=HH:MM
           Optional. Start time for result interpretation.

       --end=HH:MM
           Optional. End time for result interpretation.

       --tubedistance=meters (floating point)
           Optional. This value represents the distance between the two rubber
           tubes.  Default is 3.3 meters.

       --maxspeed=km/h (integer)
           Optional. Maximum speed allowed for interpreation. Default is 70
           km/h.

       --minspeed=km/h (integer)
           Optional. Minimum speed allowed for interpreation. Default is 5
           km/h.

       --minaxllen=meters (floating point)
           Optional. Mimium distance between axles of a vehicle. Default is
           0.5 meters.

       --maxaxllen=meters (floating point)
           Optional. Maximum distance between axles of a vehicle. Default is
           14 meters.

       --maxspeedvariation=percent (integer)
           Optional. Maximum speed variation between axles of a vehicle.
           Default is 5 %. Needed in order to figure out if two axles belong
           to the same vehicle.

       --bouncereject=seconds (floating point)
           Optional. Rejects pulses that are too close to each other time-
           wise.  Sometimes caused by heavy vehicles that makes the rubber
           tube bounce.  Default value is 0.040 seconds.

       --careful=integer
           Optional. Fine tunes the internal logic. Controls how many axles we
           calcuate from pulses in hard places before we decide to delete
           impossible axles. Default is 34, but values lower that 34 is known
           to give almost as good results by using significantly less CPU.
           Higher values than 34 does not necessarily give better results.

       --export
           Optional. Enable export output. This will just print the passing
           time of each vehicle in the format: [HH]:[MM]:[SS]. This format is
           required for apiformat.pl.

       --debug
           Optional. Enables debug output. Makes api.pl print debug
           information as well as normal output. It will make it print each
           detected axle, when it enters 'careful mode' and when it gives up
           trying to combine pulses into axle or axles into vehicles. Debug
           info is printed to STDOUT, but is easily grepable since each debug
           line starts with the text '[debug]'.

CAVEATS
   Noticed problems
       o       Heavy vehicles sometimes causes bounces. We're using bounce
               reject set to 40 milliseconds by default

       o       Light MC's sometimes doesn't cause enough pressure for pulses.
               Incomplete pulse patterns will be ignored

       Two vehicles passing the tubes in each direction at almost the same
       time are hard to deal with. This program uses brute force to combine
       all pulses to axles in such situations.

   Limitations
       o   No more that 2 axles

           This program doesn't support vehicles with more that two axles.
           This however doesn't seem to affect the interpreation accuracy
           much.

       o   Only channel 01 and 00

           We don't support any other channels in TMS Logger data than 01 and
           00.

       o   No Time-Pass Variation or Car-Follow Critera

           Brute force is used when needed.

       o   No fine tuning of vehicle definitions

           There is no option to fine tune the vehicle definitions. This is
           seldomly needed anyway.


apiformat.pl
------------
NAME
       apiformat - axle passage formatter

SYNOPSIS
       apiformat.pl [--interval=minutes]

DESCRIPTION
       apiformat.pl formats the output from api.pl into vehicles by given time
       period.

       The input format is [hour]:[minute]:[second]. Use api.pl --export to
       get this format.

       The output format is [hour:minute];[num of vehicles during this time
       period].

OPTIONS
       --interval=minutes
           Reporting interval


expexcel.pl
-----------
NAME
       expexcel - export data to MS Excel and display a chart

SYNOPSIS
       expexcel.pl [filename ...]

DESCRIPTION
       expexcel.pl tries to start MS Excel using OLE/COM, print data and
       display a chart using data from standard input or given input files.
       The columns in the input data must be separated using semicolons.
       Suitable to use in combination with the resformat.pl program.


resformat.pl
------------
NAME
       resformat - prints number of vehicles passing during each second

SYNOPSIS
       resformat.pl [--vissim] [--nr=number or route] [--vissim-file=filename]
       [filename ...]

DESCRIPTION
       resformat.pl accepts these types of input

       o   restid.pl using --verbose-export and --nostats in restid.pl
           (default)

           The input format is read as:

           [completion time];[route];[veh id];[vehicle type];[travel time]

           Where [completion time] is the number of seconds from the start of
           SAVA-measurement with one decimal precision. [route] is the route
           that was used (eg. 1->2 or 4->3). [vehicle type] is the vehicle
           type as a string (eg. Car), see the documentation to api.pl for
           details. [travel time] is the travel time in seconds with 0 to 2
           decimal precision.

           A dot is used as decimal separator.

       or/and

       o   vissim rsr-file (using --vissim or --vissim-file)

           The input format is read as:
           [completion time];[section];[veh id];[veh type];[travel time];

           Where [completion time] is calculated from the start of VISSIM-
           simulation with one decimal precision.  [section] is the travel
           time section. Use the --nr option to use desired section. [veh id]
           is vehicle number as an unique vehicle identifier during
           simulation. [veh type] is the VISSIM vehicle type identifier (eg.
           100). [travel time] is travel time in seconds with one decimal
           precision.

           A dot is used as decimal separator.

       The program then outputs a list for the number of vehicles passing
       during each second, starting with second one.

       The output is suitable for creating a chart in e.g. MS Excel. It also
       adds the input format type at the beginning of the data as a field so
       that Excel uses it as name.

       Typically the graph will look like some sort of waveform.

OPTIONS
       resformat.pl accepts the following options:

       --vissim
           Input data from standard input or ending filename is of rsr-type
           from vissim.

       --nr=number or route
           Only use the given 'travel time section'-number with vissim input.
           Or, only use the give route with SAVA-input. Where 'route' is
           [start line]->[end line]. eg. "4->3" where 4 is the start line and
           3 is the end line.

       --vissim-file=filename
           Read vissim-data from given filename as well. Creates an extra
           column in output.

restid.pl
---------
NAME
       restid - prints statistics from SAVA output

SYNOPSIS
       restid.pl [--startline=startline1[,startline2..]]
       [--waitline=waitline] [--endline=endline1[,endline2..]] [--verbose]
       [--verbose-export] [--nostats] [--vissim] [--convert]
       [--convert-file=filename] [filename]...

DESCRIPTION
       restid.pl reads the output from SAVA program and prints
       statistics about travel time.

       Valid SAVA-input data processed here are on the format

       [time] [veh type] [veh id]   L [line nr]

       Where [time] is on the format HH:MM:SS:MSS (MSS=millisecond).  [veh
       type] is a text string describing the type of vehicle.  [veh id] is a
       unique vehicle identification number.  [line nr] SAVA virtual line.
       There may be a variable amount of whitespace before the 'L'.

       Print the following statistics:
       * Calculate arrival flow for each vehicle type
       * Calculate average delay

OPTIONS
       restid.pl accepts the following options:

       --startline=startline
               Required. The number(s) of the starting line(s) which the
               vehicle passes or might pass. If you enter several numbers,
               separate them with a comma (",").

       --waitline=waitline
               Optional. The number of the waiting/stop line. Used if the
               vehicle needed to stop due to red light.

       --endline=endline
               Required. The number(s) of the ending line(s) which the
               vehicles passes or might pass. If you enter several numbers,
               separate them with a comma (",").

       --verbose
               Display each travel time calculated (like Vissim's 'raw'
               option).

       --verbose-export
               Like --verbose, excepts outputs a semicolon (";") separated
               list, suitable for export. The decimal separator used is a dot
               (".").  Format:

               [completion time];[route];[veh id];[vehicle type];[travel time]

               Where [completion time] is the number of seconds from the start
               of the SAVA-measurement.

       --nostats
               No statistics will be printed (only makes sense if used in
               combination with --verbose or --verbose-export).

       --vissim
               Output traffic volume and routing relative flow in a format
               compatible with visperl.pl Deprecated. visperl.pl contains
               neccecary logic itself.

       --convert
               Convert line numbers present in the Sava input data to Vissim
               veh inp numbers. e.g. 1=4 to turn line number 1 into Vissim veh
               inp 4.  Separate each conversion with a comma. e.g. --convert
               1=4,4=32 Note: This option only works in combination with the
               --vissim option.

       --convert-file=filename
               Read sava line to vissim input-/desc/route no from a file. See
               --convert Separate each conversion with a new line. Lines
               beginning with a '#' -character is considered a comment.  Note:
               This option only works in combination with the --vissim option.

CAVEATS
       --waitline only accepts one number.


visperl.pl
----------
Typical usage:
- Starts Vissim
- Load network
- Modify Vissim settings (output data to files)
- Run simulation
- Save output and rename
- Close Vissim

NAME
       visperl - run Vissim simulation and save the results

SYNOPSIS
       visperl.pl [--path=path] [--net=filename] [--rsz=filename]
       [--rsr=filename] [--period=seconds] [--iterations=no of iterations]
       [--increase_all_volume=percent]
       [--increase_vehinp_volume=[vehinp1,vehinp2=%]:[vehinp3=%]]
       [--input=[veh inp=volume],..]  [--route=[routing
       decision:route=relative traffic flow],..]  [--nullify-unused]
       [--stdopt] [--compile] [--stat] [--verbose]
       [--sava-startline=[line1],[line2],..]
       [--sava-endline=[line1],[line2],..]  [--sava-convert-file=filename]
       [--route-type-file=filename] [--reality] [--api-start=HH:MM]
       [--api-end=HH:MM] [--api-control-file=filename] [--ec1-controller=path
       to ec1-project] [--fill-unused] [--mail-smtp=hostname]
       [--mail-from-addr=e-mail] [--mail-from-name=name]
       [--mail-subject=subject line] [--mail-to=[e-mail],..]
       [--config=filename]

DESCRIPTION
       visperl.pl runs a Vissim simulation using the given project file. It
       can modify certain properties in Vissim (e.g. traffic volume,
       simulation period) and rename log file of travel times to a custom name
       when done.

OPTIONS
       --path=path
               Optional. This is the path to the Vissim project directory. Can
               be used to find the Vissim project file (not required) and to
               rename the rsz- or rsr file if the --rsz or --rsr option has
               been given.

       --net=filename
               Required. The Vissim project file (without the path if --path
               has been given).

       --rsz=filename
               Optional. Enables logging of compiled travel time.  Requires
               the use of the --path option.  Renames the resulting rsz-file
               to given filename.

       --rsr=filename
               Optional. Enables logging of raw travel time.  Requires the use
               of the --path option.  Renames the resulting rsr-file to given
               filename.

       --period=seconds
               Optional. Run the simulation at given number of seconds.
               Otherwise it just uses whatever's default in the project file.

       --iterations=no of iterations
               Optional. Run the simulation given amount of times to ensure
               the reliability of the simulation results. Default is 1
               iteration.

       --increase_all_volume=percent
               Optional. Increase all individual traffic volumes by given
               number of percent.  Enter integers; e.g. --set_all_volume=10
               means 10% increase of traffic volume.

       --increase_vehinp_volume=[vehinp1,vehinp2=%:vehinp3=%]
               Optional. Increase individual traffic volumes for each vehicle
               input number e.g. --increase_vehinp_volume=4,5=10:6=15. This
               adds 10 % to vehicle input 4 and 5, and 15 % to vehicle input
               6..

       --input=[[veh inp=volume],..]
               Optional. Set an exact value of traffic flow in veh/h. e.g.
               --input=4:100 where 4 is the Vehicle input number and 100 is
               the traffic flow in vehicles per hour.

       --route=[[routing decision:route=relative traffic flow],..]
               Optional. Set the relative traffic flow for a route. e.g.
               --route=1:3=100 where 1 is the routing decision, 3 is the route
               number and 100 is the relative traffic flow.

       --nullify-unused
               Optional. Sets unset vehicle inputs or routing rel. flow (using
               --input or --route) to 0. Ignore if --input or --route is not
               used.  Useful if your traffic statistics doesn't include all
               inputs/routes.

       --stdopt
               Optional. Sets options using standard input instead. Remove the
               double dash ('--') before each option. Use a newline to
               separate each option.  e.g. input=1=51,2=9 on STDIN.

       --compile
               Optional. Outputs compiled travel time statistics similar to
               the one restid.pl produces. Bases it's output on the statistics
               that the Vissim rsz-file produces.

       --stat  Optional. Outputs self produced statistics based on raw travel
               times from the rsr-file Vissim produces. Includes max, min,
               variance, and standard deviation.

       --verbose
               Optional. Increase verbosity level. Outputs status whenever
               changing vissim parameters.

       --sava-startline=[line1],[line2],..
               Activates processing of SAVA-data. The numbers(s) or the
               starting line(s) which the vehicle passes or might pass. If you
               enter several numbers, separate them with a comma (',').

       --sava-endline=[line1],[line2],..
               The number(s) of the ending line(s) which the vehicles passes
               or might pass.  If you enter several numbers, separate them
               with a comma (',').

       --sava-convert-file=filename
               Use a file with each sava-data-files printed on each line,
               instead of specifying each sava-file as argument.

       --route-type-file=filename
               Use a file to describe of what type a traffic route is of. This
               produces statistics that also separates types of traffic.

       --reality
               Compare with reality. Prints SAVA-statistics at the end.

       --api-start=HH:MM
               Specifies the start time for result interpretation.

       --api-end=HH:MM
               Specifies the end time for result interpretation.

       --api-control-file=filename]
               Enables the Axle Passage Interpreter to determine a accurate
               vehicle flow.  API control file which must contain each API-
               data file with it's vehicle input number and file name seprated
               with a semi-colon, on each line.
       --ec1-controller=path to ec1-project
               Use specified EC-1 controller

       --fill-unused
       --mail-smtp=hostname
               E-mail the results. Specifies the hostname of the SMTP-server
               required to send the email.

       --mail-from-addr=e-mail
               The resulting e-mail will look like it came from this e-mail-
               address.

       --mail-from-name=name
               The resulting e-mail will look like it came from this name. Use
               (")-chars when appropriate.

       --mail-subject=subject line
               Subject line. Use (")-chars when approriate.

       --mail-to=[e-mail],..
               Send the e-mail to these addresss. Separate each address with a
               (,)-char.

       --config, -f=filename
               Instead of specifying each option on the command line, use a
               config-file.  All options avalible on the command line is also
               avalible in the config-file.  Just omit the double dash (--) in
               front of each option. One option per line.  Don't use the '='
               char to separate option from parameter, use blankspace.  Empty
               lines and lines beginning with a '#'-char are ignored.

CAVEATS
       Remaining issues

       Start of the EC1-simulator might fail
               Sometimes visperl is unable to find the EC1-simulator "License"
               message-box window and is therefore unable to start the
               simulator properly.

       Errors are not logged properly
               Any errors or warnings that occur is printed on STDERR and is
               not included with the e-mail. It is therefore easy to miss any
               errors that might have affected the outcome.

       Number of necessary simulations
               It is possible to calculate the number of needed simulations.
               Or when another simulation wouldn't change the total outcome in
               a simulation significantly.

ttstat.pl
---------
NAME
       ttstat - travel time statistics

SYNOPSIS
       ttstat.pl --vissim --convert --convert-file

DESCRIPTION
       ttstat.pl prints various forms of statistics from travel times.

       travel times is read on the form

       [completion time];[route];[veh id];[vehicle type];[travel time]

OPTIONS
       --vissim

       Output traffic volume and routing relative flow in a format compatible
       with visperl.pl

       --convert

       Convert line numbers present in the Sava input data to Vissim veh inp
       numbers. e.g. 1=4 to turn line number 1 into Vissim veh inp 4.
       Separate each conversion with a comma. e.g. --convert 1=4,4=32 Note:
       This option only works in combination with the --vissim option.

       --convert-file

       Read sava line to vissim input-/desc/route no from a file. See
       --convert Separate each conversion with a new line. Lines beginning
       with a '#' -character is considered a comment.  Note: This option only
       works in combination with the --vissim option.

spool.pl
--------
Simple queue system for simulations

