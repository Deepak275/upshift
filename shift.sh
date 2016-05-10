#!/bin/bash

# 1. Read the configuration files
debug=false
alwaysCleanBeforeBuild=true
alwaysUninstallOlderBuilds=true
package=""
mainActivity=""
gitRepositoryBranch=""
masterPassword=""
projectName=""
useWorkspace=false
scheme=""
iPhone="iPhone 6"
iPhoneOS=" (9.3)"
xcodeVersion="7.3"

# 2. Load up config from config file
if [ -f "./config.cfg" ]; then
  source ./config.cfg
fi

# 3. Dump commands to the screen, only if one wants to debug
if [ "${debug}" == true ];then
  set -v
fi

# 4. Make sure things look good. Here are some font and color adjustments
redColour='\033[0;31m'
greenColour='\033[0;32m'
blueColour='\033[0;34m'
noColour='\033[0m'

boldStyle=$(tput bold)
normalStyle=$(tput sgr0)

# 5. Exit script on error
# set -e
# (Maye not)

# 6. Setup Global Variables
next=true
platform=$1
job=$2





# Setup Internal Functions

function StartScript {
  printf "${greenColour}
###############################################################
##              Booting up the engines..                     ##
###############################################################
${noColour}"
}

function EndScript {
  printf "\n"
}

function ShowError {
  printf "${redColour}
################## Boom! Something went wrong! ################
${noColour}"
}

function ShowPreviousFailed {
  printf "${redColour}Skipping${noColour} action because the previous actions failed\n"
}

function StartAction {
  printf "${blueColour}
############ Starting next action : $1 ##############
${noColour}\n"
}

StartScript





# Setup Actions

##
## setup-ssh
## 

function SetupSSH {

  StartAction "SetupSSH"

  # Details about the script came from here
  # https://help.github.com/articles/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent/

  # If 'next' is false, exit
  if [ ${next} == false ]; then
    ShowPreviousFailed
    return
  fi

  # Check if email has been defined by the user
  if [ "${emailForSSHKey}" != "" ]; then
    # TODO : Allow the user to add the keys to a non default place
    # Check if an id_rsa already exists at the defualt location
    if [ ! -f ~/.ssh/id_rsa ]; then
      printf "File does not exist at ~/.ssh/id_rsa"
      echo -ne '\n' | ssh-keygen -t rsa -b 4096 -C "${emailForSSHKey}"

      # Show the created keys on the screen
      ID_RSA=$(<~/.ssh/id_rsa)
      ID_RSA_PUB=$(<~/.ssh/id_rsa.pub)

      printf "${boldStyle}id_rsa${normalStyle}\n"
      printf "${ID_RSA}"
      printf "\n\n${boldStyle}id_rsa.pub${normalStyle}\n"
      printf "${ID_RSA_PUB}"

      printf "All done 🍺\n"

    else
      ShowError
      printf "Can't do this, looks like an id_rsa already exists at ~/.ssh/id_rsa, get rid of that first\n"
      next=false
    fi
  else
    ShowError
    printf "Dude, you need to add the <${redColour}emailForSSHKey${noColour}> parameter to get this to work\n"
    next=false
  fi
}

##
## install-on-android
##

function InstallOnAndroid {

  StartAction "InstallOnAndroid"

  # If 'next' is false, exit
  if [ ${next} == false ]; then
    ShowPreviousFailed
    return
  fi

  # Make a TIMESHTAMP for the log file
  TIMESHTAMP=$(date +%Y%m%d%H%M%S)

  # TODO : Add the project name to the logfile and move it to a common location on the server
  # TODO : Use the logs to show details on a screen somewhere

  # If alwaysCleanBeforeBuild then run clean
  if [ "${alwaysCleanBeforeBuild}" == true ]; then
    printf "Time to ${greenColour}clean up${noColour}\n\n"
    ./gradlew clean 2>&1 | tee gradle-clean-$TIMESHTAMP.log
  else
    printf "Skipping :clean:, you have ${blueColour}alwaysCleanBeforeBuild${noColour} turned off\n"
  fi

  # Uninstall older builds if the setting so desires
  if [ "${alwaysUninstallOlderBuilds}" == true ]; then
    printf "Time to ${greenColour}uninstall${noColour} older builds\n\n"
    ./gradlew uninstallAll 2>&1 | tee gradle-uninstall-$TIMESHTAMP.log
  else
    printf "Skipping :uninstallAll:, you have ${blueColour}alwaysUninstallOlderBuilds${noColour} turned off\n"
  fi

  # Now time to build again
  printf "\nTime to run ${greenColour}installDebug${noColour} on this thing\n\n"
  ./gradlew installDebug --stacktrace 2>&1 | tee gradle-install-$TIMESHTAMP.log

  # Get the logged results and try to make some sense out of it
  BUILD_RESULTS=$(<gradle-install-$TIMESHTAMP.log)

  # When you build via Gradle, it seems it always sends BUILD SUCCESSFUL in the results
  # This could mess up if in some build configuration, there are two messages, one is BUILD SUCCESSFUL and one otherwise
  BUILD_SUCCESSFUL=$(echo $BUILD_RESULTS | grep "BUILD SUCCESSFUL" -c)

  # If the build was successful, let 'em know
  if [ "$BUILD_SUCCESSFUL" != "1" ]; then
    ShowError
    printf "Damn, it looks like something went ${redColour}wrong${noColour}. You should check this up.\n\n"
    next=false
  else
    printf "\n\n${greenColour}Super${noColour}! The build was fine.\n"
    # TODO : Someday figure out how to get package and mainActivity automatically
    # Check if package is empty
    if [ "${package}" != "" ];then
      if [ "${mainActivity}" != "" ]; then
        printf "Starting activity ${blueColour}${mainActivity}${noColour} in package ${blueColour}${package}${noColour}\n"

        # Start the activity and package
        adb shell am start -n ${package}/${package}.${mainActivity}

        # Tell the user everything is nice and easy
        printf "\nAlright, the build was ${greenColour}successful${noColour} 🍺\n\n"
      else
        # The mainActivity is empty it seems
        printf "Alright, the build was ${greenColour}successful${noColour}, but there was no ${blueColour}mainActivity${noColour} defined, so couldn't start it automatically 🍺\n\n"
      fi
    else
      # The package is empty it seems
      printf "Alright, the build was ${greenColour}successful${noColour}, but there was no ${blueColour}package${noColour} defined, so couldn't start it automatically 🍺\n\n"
    fi
  fi
}

##
## git-pull
##

function GitPull {

  StartAction "GitPull"

  # If 'next' is false, exit
  if [ ${next} == false ]; then
    ShowPreviousFailed
    return
  fi

  # Make a TIMESHTAMP for log file
  TIMESHTAMP=$(date +%Y%m%d%H%M%S)

  # Check if the branch name is defined
  # TODO : Automatically pick the current branch
  if [ "${gitRepositoryBranch}" != "" ]; then

    printf "Alright, let's ${greenColour}pull${noColour} the ${gitRepositoryBranch} branch for this repo\n\n"

    # Alright, let's pull
    git pull origin ${gitRepositoryBranch} 2>&1 | tee git-pull-$TIMESHTAMP.log

    # Load up the results to see if there were any errors
    PULL_RESULTS=$(<git-pull-$TIMESHTAMP.log)
    # If there was a fatal error, tell the user there's something wrong
    if [ "$(printf "${PULL_RESULTS}" | grep "fatal:" -c)" -gt "0" ] || [ "$(printf "${PULL_RESULTS}" | grep "error:" -c)" -gt "0" ]; then
      ShowError
      printf "Something went wrong with the pull, you should look this up\n\n"
      next=false
    else
      # All done
      printf "\nAll done ${greenColour}baby${noColour}! 🍺.\n\n"
    fi

  else
    # The user hasn't added the required keys
    ShowError
    printf "Dude, you need to add the ${blueColour}gitRepositoryBranch${noColour} for this to work\n\n"
    next=false
  fi
}

##
## git-clone
##

function GitClone {

  StartAction "GitClone"

  # If 'next' is false, exit
  if [ ${next} == false ]; then
    ShowPreviousFailed
    return
  fi

  # Make a TIMESHTAMP for log file
  TIMESHTAMP=$(date +%Y%m%d%H%M%S)

  # Check if the repo URL is defined
  if [ "${gitRepositoryURL}" != "" ]; then
    # Check if the branch name is defined
    # TODO : Automatically pick the current branch
    if [ "${gitRepositoryBranch}" != "" ]; then

      printf "Alright, let's ${greenColour}clone${noColour} the ${blueColour}${gitRepositoryBranch}${noColour} branch for the ${blueColour}${gitRepositoryURL}${noColour} repo\n\n"
    
      # Alright, let's pull
      # But you can't pull into an empty directly, now since you already have bitrise.yml and .bitrise.secrets.yml in your directory,
      #   you will need to clone into another folder, and move stuff back here
      #   we can't do what the rest of the world tries to do - which is git init, add remote,
      #   because we want to ensure we do depth=1 and not download the whole repo, which can be painful at times
      git clone -b ${gitRepositoryBranch} ${gitRepositoryURL} tmp --depth 1  2>&1 | tee git-clone-$TIMESHTAMP.log
      mv tmp/* . 2>&1 | tee git-clone-$TIMESHTAMP.log
      mv tmp/.* . 2>/dev/null | tee git-clone-$TIMESHTAMP.log
      rm -rf tmp/ 2>&1 | tee git-clone-$TIMESHTAMP.log

      # Load up the results to see if there were any errors
      CLONE_RESULTS=$(<git-clone-$TIMESHTAMP.log)
      # If there was a fatal error, tell the user there's something wrong
      if [ "$(printf "${CLONE_RESULTS}" | grep "fatal" -c)" -gt "0" ] || [ "$(printf "${CLONE_RESULTS}" | grep "error" -c)" -gt "0" ]; then
        ShowError
        printf "Something failed while we were cloning, you should look this up\n\n"
        next=false
      else
        # All done
        printf "\nAll done ${greenColour}baby${noColour}! 🍺.\n\n"
      fi

    else
      # The user hasn't added the required keys
      ShowError
      printf "Dude, you need to add the ${blueColour}gitRepositoryBranch${noColour} for this to work\n\n"
      next=false
    fi
  else
    # The user hasn't added the required keys
    ShowError
    printf "Dude, you need to add the ${blueColour}gitRepositoryURL${noColour} for this to work\n\n"
    next=false
  fi
}

##
## start-emulator
##

function StartEmulator {

  StartAction "StartEmulator"

  # If 'next' is false, exit
  if [ ${next} == false ]; then
    ShowPreviousFailed
    return
  fi

  # TODO : Create an emulator if one doesn't exist
  # TODO : Maybe run ./gradlew connectedCheck to see if everything is working fine

  # Check if Boot Animation is still on
  # https://devmaze.wordpress.com/2011/12/12/starting-and-stopping-android-emulators/
  # adb shell getprop init.svc.bootanim
  # We don't really care about this right now

  # Check if a process which calls itself the emulator is running
  # TODO : may check this using ADB Devices
  # TODO : Gets fucked up when adb fucks up, keeps ranting multiple devices found (not the exact message)
  OUTPUT=$(ps -aef | grep emulator | grep "sdk/tools" -c)
  # If 0 processes are called emulator, it means we need to load up one
  if [ "$OUTPUT" == "0" ]; then

    if [ "${emulatorName}" != "" ]; then

      EMULATOR_RESULTS=$(nohup $ANDROID_HOME/tools/emulator -avd ${emulatorName} 2>emulator.log 1>emulator.log &)
      # TODO : This is a big #HACK, only errors are returned in the first two seconds, I suck and I don't know a way out
      # TODO : Another potential problem, we redirect both 1,2 in reset mode (>), the file could get overwritten
      sleep 2
      EMULATOR_RESULTS=$(<emulator.log)
      
      # Check if there was a PANIC [to test this, put in the wrong emulator name]
      PANIC_COUNT=$(echo ${EMULATOR_RESULTS} | grep "PANIC" -c)

      # If there was a panic, throw it at the user, they messed up, not us
      if [ "${PANIC_COUNT}" -gt 0 ]; then
        ShowError
        printf "The emulator won't load up. Maybe the ${redColour}emulatorName${noColour} key isn't correct\n"
        printf "Here's what Mr. Log says:\n\n"
        printf "${EMULATOR_RESULTS}\n\n"
        next=false
      else 
        # Seems like there is no panic, let's check for errors
        # TODO : Can't remember how do you get an error
        ERROR_COUNT=$(echo ${EMULATOR_RESULTS} | grep "ERROR" -c)

        if [ "${ERROR_COUNT}" -gt 0 ]; then
          printf "${EMULATOR_RESULTS}\n\n"
          next=false
        else
          printf "All set baby, ${greenColour}starting${noColour} to load up the emulator\n"
          # ADB gives this option to wait for the device till it comes up, let's just depend on it, 
          # this is really mess with us when there is a problem with the emulator fails to load because of it's own bugs
          adb wait-for-device

          # Now that the device is available, the worst is over
          # Check if the emulator has finished botting, if not, sleedp for 2 seconds and try this again, this is our final trigger
          printf "Seems like the device is now ${greenColour}available${noColour}, we are getting close\n"
          SCREEN_LOADING=$(adb shell getprop sys.boot_completed | tr -d '\r')
          while [ "$SCREEN_LOADING" != "1" ]; do
            sleep 4
            printf "Check if the emulator has finished booting, why is this thing so ${blueColour}damn${noColour} slow?\n"
            SCREEN_LOADING=$(adb shell getprop sys.boot_completed | tr -d '\r')
          done

          # Alright, everything is now done. This is just used to unlock the device.
          printf "Almost ${greenColour}done${noColour}, touch the device once\n"
          adb shell input keyevent 82
          printf "${greenColour}Super!${noColour} The emulator is now running. You're one lucky person 🍺\n"
        fi
      fi

    else 
      ShowError
      printf "Dude, you need to define ${blueColour}emulatorName${noColour} for this to work\n\n"
      next=false
    fi
  else
    printf "${greenColour}Dude${noColour}, Looks like the emulator is already running!\n\n"
  fi
}

##
## android-devices
##
function AndroidDevices {

  StartAction "AndroidDevices"

  # If 'next' is false, exit
  if [ ${next} == false ]; then
    ShowPreviousFailed
    return
  fi

  # Touch device to that they can get unlocked, otherwise ADB just ignores them
  # Just make sure you hide the STDERR because well we don't care too much about it
  TOUCH_DEVICE=$(adb -d shell input keyevent 82 2>&1)

  # Find out how many devices are available, and are not emulators
  DEVICES_FOUND=$(adb devices | grep -v "List of devices attached" | grep -v emulator -c)
  # For some reason we get one added to the value, so let's just substract it
  let DEVICES_FOUND=DEVICES_FOUND-1;

  # Show appropriate error message
  if [ "${DEVICES_FOUND}" -gt 0 ]; then
    printf "${DEVICES_FOUND} physical device(s) were found 🍺\n\n"
  else
    ShowError
    printf "No physical devices were found\n\n"
    next=false
  fi
}

##
## assemble-android
##
function AssembleAndroid {

  StartAction "AssembleAndroid"

  # If 'next' is false, exit
  if [ ${next} == false ]; then
    ShowPreviousFailed
    return
  fi
 
  # Make a TIMESHTAMP for log file
  TIMESHTAMP=$(date +%Y%m%d%H%M%S)

  # TODO : Add the project name to the logfile and move it to a common location on the server
  # TODO : Use the logs to show details on a screen somewhere

  # If alwaysCleanBeforeBuild then run clean
  if [ "${alwaysCleanBeforeBuild}" == true ]; then
    printf "Time to ${greenColour}clean up${noColour}\n\n"
    ./gradlew clean 2>&1 | tee gradle-clean-$TIMESHTAMP.log
  else
    printf "Skipping :clean:, you have ${blueColour}alwaysCleanBeforeBuild${noColour} turned off\n"
  fi

  # Now time to build again
  printf "\nTime to run ${greenColour}assembleDebug${noColour} on this thing\n\n"
  ./gradlew assembleDebug --stacktrace 2>&1 | tee gradle-assemble-$TIMESHTAMP.log

  # Get the logged results and try to make some sense out of it
  BUILD_RESULTS=$(<gradle-assemble-$TIMESHTAMP.log)

  # When you build via Gradle, it seems it always sends BUILD SUCCESSFUL in the results
  # This could mess up if in some build configuration, there are two messages, one is BUILD SUCCESSFUL and one otherwise
  BUILD_SUCCESSFUL=$(echo $BUILD_RESULTS | grep "BUILD SUCCESSFUL" -c)

  # If the build was successful, let 'em know
  if [ "$BUILD_SUCCESSFUL" != "1" ]; then
    ShowError
    printf "Damn, the build was not ${redColour}successful${noColour}. You should check this up.\n\n"
    next=false
  else
    printf "\nAlright, the build was ${greenColour}successful${noColour} 🍺\n\n"
  fi
}

##
## Setup Submodule if they exist
##

function GitSubmodules {

  StartAction "GitSubmodules"

  # If 'next' is false, exit
  if [ ${next} == false ]; then
    ShowPreviousFailed
    return
  fi

  # Make a TIMESHTAMP for log file
  TIMESHTAMP=$(date +%Y%m%d%H%M%S)

  # Check if .gitmodules exists
  if [ -f ".gitmodules" ]; then
    # If the file exists, we need to run init and update and catch errors
    git submodule init 2>&1 | tee git-submodule-init-$TIMESHTAMP.log
    git submodule update 2>&1 | tee git-submodule-update-$TIMESHTAMP.log

    SUBMODULE_RESULTS=$(<git-submodule-update-$TIMESHTAMP.log)

    if [ $(echo ${SUBMODULE_RESULTS} | grep "fatal:" -c) -gt 0 ] || [ $(echo ${SUBMODULE_RESULTS} | grep "error:" -c) -gt 0 ]; then
      ShowError
      printf "Damn, initializing submodules was ${redColour}not successful${noColour}. You should check this up.\n\n"
      next=false
    else
      printf "\nSubmodules are now ${greenColour}setup${noColour}, one less thing to think about! 🍺\n\n"
    fi
    # Else Quietly ignore
  else
    printf "\nIt looks like this project doesn't use ${greenColour}submodules${noColour}.\n\n"
  fi
}

##
## Install pods if they exist
##

function SetupPods {

  StartAction "SetupPods"

  # If 'next' is false, exit
  if [ ${next} == false ]; then
    ShowPreviousFailed
    return
  fi

  # Make a TIMESHTAMP for log file
  TIMESHTAMP=$(date +%Y%m%d%H%M%S)

  # Check if Podfile exits
  if [ -f "Podfile" ]; then
    # Check if cocoapods is installed
    POD_VERSION=$(pod --version 2>&1)
    POD_INSTALLED=$(grep 'command not found' -c <<< ${POD_VERSION})

    if [ "${POD_INSTALLED}" -gt 0 ]; then
      # Cocoapods is not installed, let's install it first
      # First check if the master password has been defined
      if [ "${masterPassword}" != "" ]; then
        # TODO : test this on an actual machine
        echo -ne ${masterPassword} | sudo -S gem install cocoapods
        # TODO : Catch error from install cocoapods

        # https://guides.cocoapods.org/using/pod-install-vs-update.html
        # We want to keep pods on their own version, hence not updating
        pod install
        # TODO : Catch errors from pod install

        printf "\nPods are now ${greenColour}up to date${noColour}, one less thing to think about! 🍺\n\n"
      else
        ShowError
        printf "Alright, so it seems we need to install cocoapods and that requires\nadmin permissions. You need to add  ${redColour}masterPassword${noColour} to your config\nfor this to work.\n"
        next=false
      fi
    else
      # Given that cocoapods is installed
      # https://guides.cocoapods.org/using/pod-install-vs-update.html
      # We want to keep pods on their own version, hence not updating
      pod install
      # TODO : Catch errors from pod install
    fi
  else
    printf "\nIt looks like this project doesn't use ${greenColour}pods${noColour}. You're awesome!\n\n"
  fi
}

##
## Get the XCode version in use
##
function XCodeVersion {

  StartAction "XCodeVersion"

  XCODE_VERSION=$(xcodebuild -version | grep "Xcode" | tr -d "Xcode ")
  printf "We are currently using XCode ${blueColour}${XCODE_VERSION}${noColour}\n\n"

  if [ "${XCODE_VERSION}" != "${xcodeVersion}" ]; then
    # Looks like the xcode version required and available do not match
    # Check if this system has the XCode version required
    # TODO : This will vary based on how you setup XCode, find out if there is a better way
    if [ -d "/Applications/Xcode-${xcodeVersion}.app/" ]; then
      # Looks like this version is available on this machine

      # Check if the user has added the password for this machine, we need sudo again
      if [ "${masterPassword}" != "" ]; then
        # Alright, it seems there is a password, let's try it out
        printf "${blueColour}Switching${noColour} Xcode versions\n\n"
        echo -ne ${masterPassword} | sudo xcode-select -switch "/Applications/Xcode-${xcodeVersion}.app/"

        # Maye it's done, check and confirm
        XCODE_VERSION=$(xcodebuild -version | grep "Xcode" | tr -d "Xcode ")

        if [ "${XCODE_VERSION}" == "${xcodeVersion}" ]; then
          printf "We are now using XCode ${blueColour}${XCODE_VERSION}${noColour}\n"
        else
          ShowError
          printf "Something went wrong. Maybe we messed up big time or the password that you entered was wrong.\n\n"
          next=false
        fi

      else
        ShowError
        printf "Alright, so we need the sudo password to change the Xcode version.\nWould you be a sweetheart and add it\nto the ${blueColour}masterPassword${noColour} key in the config\n\n"
        next=false
      fi
    else
      ShowError
      printf "We do not have XCode ${xcodeVersion} on this machine. About time to get it.\n\n"
      next=false
    fi
  fi

}

##
## Install xcpretty
##
function XCPretty {

  # TODO : Add XCPretty to a Job
  # TODO : Allow user to update XCPretty
  StartAction "XCPretty"

  # If 'next' is false, exit
  if [ ${next} == false ]; then
    ShowPreviousFailed
    return
  fi

  XCPRETTY_VERSION=$(xcpretty --version 2>&1)
  XCPRETTY_INSTALLED=$(grep 'command not found' -c <<< ${XCPRETTY_VERSION})

  if [ "${XCPRETTY_INSTALLED}" -gt 0 ]; then
    # XCPretty is not installed, let's install it first
    # First check if the master password has been defined
    if [ "${masterPassword}" != "" ]; then
      # TODO : test this on an actual machine
      echo -ne ${masterPassword} | sudo -S gem install xcpretty
      # TODO : Catch error from install xcpretty

      printf "\nXCPretty is now ${greenColour}installed${noColour}, one less thing to think about! 🍺\n\n"
    else
      ShowError
      printf "Alright, so it seems we need to install xcpretty and that requires\nadmin permissions. You need to add  ${redColour}masterPassword${noColour} to your config\nfor this to work.\n"
      next=false
    fi
  else
    printf "Woot! XCPretty is already installed\n"
  fi
}

##
## iOS Build Project
##
function BuildiOS {

  StartAction "BuildiOS"

  # If 'next' is false, exit
  if [ ${next} == false ]; then
    ShowPreviousFailed
    return
  fi

  # Make a TIMESHTAMP for log file
  TIMESHTAMP=$(date +%Y%m%d%H%M%S)

  # Either use projectName defined by the user, or pick it automatically
  if [ "${projectName}" == "" ]; then
    printf "Dude, you need to define ${redColour}projectName${noColour} in your config.\nSince you haven't, we are going to pick it automatically,\nwhich will take time on every build.\n\n"

    PROJECT_NAME_STRING=$(xcodebuild -showBuildSettings | grep PROJECT_NAME)
    projectName=${PROJECT_NAME_STRING#"    PROJECT_NAME = "}

    if [ "${projectName}" == "" ]; then
      ShowError
      printf "Damn, couldn't even find it automatically. Are you sure this is an iOS repo?\n"
      next=false
      return
    fi

    printf "Found ${blueColour}${projectName}${noColour} automatically. Using this now.\n\n"
  fi

  # Build using workspace if user asks, if it uses cocoapods user workspace automatically, othewise use xcodeproj
  PROJECT_TYPE="project"
  EXTENSION=".xcodeproj"

  if [ "${useWorkspace}" == true ]; then
    # Since the user is requesting for it, decision is done, we love our users.
    PROJECT_TYPE="workspace"
    EXTENSION=".xcworkspace"
  else
    if [ -f "Podfile" ]; then
      # If a Podfile exits, then guys use Cocoapods, load up the workspace by default
      PROJECT_TYPE="workspace"
      EXTENSION=".xcworkspace"
    fi
  fi
  
  PROJECT_PATH="${projectName}${EXTENSION}";

  # TODO : Find a way to find scheme automatically by parsing xcodebuild -list
  if [ "${scheme}" != "" ];then

    # Load up the simulator first, so that it gets ready while the build happens
    # Check if the simulator is already open
    OUTPUT=$(ps -aef | grep "Simulator.app" -c)
    if [ "${OUTPUT}" -gt 1 ]; then
      # There's a simulator already running
      printf "The simulator is already ${greenColour}running${noColour}!\n\n"
    else
      # Load up the simulator
      printf "Starting up the ${greenColour}simulator${noColour}!\n\n"
      xcrun instruments -w "${iPhone}${iPhoneOS}" 2>&1 1>/dev/null
    fi

    # Build the effing thing
    # TODO : Clean the effing thing before you start
    printf "Compiling the beautiful codebase\n\n"
    set -o pipefail && xcodebuild -${PROJECT_TYPE} ${PROJECT_PATH} -scheme "${scheme}" -hideShellScriptEnvironment -sdk iphonesimulator -destination "platform=iphonesimulator,name=${iPhone}" -derivedDataPath build | tee xcode-build-${TIMESHTAMP}.log | xcpretty

    BUILD_RESULTS=$(<xcode-build-${TIMESHTAMP}.log);
    BUILD_SUCCEDED=$(grep "BUILD SUCCEEDED" -c <<< "${BUILD_RESULTS}")

    if [ "${BUILD_SUCCEDED}" -gt 0 ]; then

      # The build succeded
      printf "The build was ${greenColour}successful${noColour} 🍺\n\n"
    else
      ShowError
      printf "It seems the build ${redColour}failed${noColour}. You need to look this up\n\n"
      next=false
    fi

  else
    ShowError
    printf "Dude, you need to define the ${blueColour}scheme${noColour} that you would like to build.\nYou can pick one here\n\n"
    xcodebuild -list
    next=false
  fi
}

##
## Deploy iOS to a simulator
##
function DeployiOSSimulator {

  StartAction "DeployiOSSimulator"

  # If 'next' is false, exit
  if [ ${next} == false ]; then
    ShowPreviousFailed
    return
  fi

  # Get the product full name
  FULL_PRODUCT_NAME=$(xcodebuild -showBuildSettings | grep FULL_PRODUCT_NAME)
  fullProductName=${FULL_PRODUCT_NAME#"    FULL_PRODUCT_NAME = "}

  # Get the bundle identifier
  PRODUCT_BUNDLE_IDENTIFIER=$(xcodebuild -showBuildSettings | grep PRODUCT_BUNDLE_IDENTIFIER)
  productBundleIdentifier=${PRODUCT_BUNDLE_IDENTIFIER#"    PRODUCT_BUNDLE_IDENTIFIER = "}

  printf "About to ${blueColour}deploy${noColour} ${fullProductName} (${productBundleIdentifier}) to the simulator\n\n"

  # TODO : Find a good way to delete the app from the simulator
  #xcrun simctl uninstall booted ${productBundleIdentifier}

  #Details here http://dduan.net/post/2015/02/build-and-run-ios-apps-in-commmand-line/

  # Deploy the app to the simulator
  xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/${fullProductName}

  # Open up the app on the simulator
  printf "Starting the app\n\n"
  xcrun simctl launch booted ${productBundleIdentifier}

}

#SetupSSH
#InstallOnAndroid
#GitPull
#GitClone
#StartEmulator
#AndroidDevices
#AssembleAndroid
#GitSubmodules
#SetupPods
#XCodeVersion
#XCPretty
#BuildiOS
#DeployiOSSimulator


# TODO : Add a function to read XCode Build Settings
#function XCodeBuildSettings {
  #xcodebuild -showBuildSettings
#}
#XCodeBuildSettings


# TODO : Find outdated pods
# pod outdated
# from here - https://guides.cocoapods.org/using/pod-install-vs-update.html


# TODO : Find all iOS Devices
# xcrun simctl list


# Setup Jobs

jobQueue=()

function RunJobs {
  for action in ${jobQueue[@]}
    do
      :
      ${action}
  done
}

function FindJobQueue {

  # TODO : Use Case for this, not if, if sucks
  if [ "${platform}" == "android" ]; then
    if [ "${job}" == "build" ]; then
      ## ANDROID ## BUILD ##
      jobQueue=("GitPull" "GitSubmodules" "AssembleAndroid")
    else
      if [ "${job}" == "emulator" ]; then
        ## ANDROID ## EMULATOR ##
        jobQueue=("StartEmulator" "GitPull" "GitSubmodules" "InstallOnAndroid")
      else
        ## ANDROID ## NOT SUPPORTED
        ShowError
        printf "Yo! We only support two commands for Android right now, build and emulator\n"
      fi
    fi
  else
    if [ "${platform}" == "ios" ]; then
      ## IOS ## BUILD ##
      if [ "${job}" == "build" ]; then
        jobQueue=("XCodeVersion" "GitPull" "GitSubmodules" "SetupPods" "BuildiOS" "DeployiOSSimulator")
      else
        ## IOS ## NOT SUPPORTED
        ShowError
        printf "Yo! We only support one commands for iOS right now: build\n"
      fi
    else
      ## SETUP ## CLONE ##
      if [ "${platform}" == "setup" ]; then
        if [ "${job}" == "clone" ]; then
          jobQueue=("GitClone" "GitSubmodules")
        else
          ## SETUP ## NOT SUPPORTED
          ShowError
          printf "Yo! We only support one commands for Setup right now: clone\n"
        fi
        
      else
        ## NOT SUPPORTED ##
        ShowError
        printf "Yo! We are not ${blueColour}supporting${noColour} this platform at this time. It's only iOS and Android at this time.\n"
      fi
    fi
  fi

}

# Start running the scripts
FindJobQueue
RunJobs




# Ending

EndScript