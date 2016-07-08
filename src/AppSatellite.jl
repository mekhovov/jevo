#
# This is application file of Satellite. It tracks some process
# and rerun it in case of crash. This is needed, because Julia has
# an issue with long term eval() function running. Github issue:
# https://github.com/JuliaLang/julia/issues/15017
#
# @author DeadbraiN
#
include("ImportFolders.jl")
import Helper
import Backup
import Config
#
# This function starts the satellite and begin watching on
# Manager application (process).
#
function main()
  if length(ARGS) < 1
    Helper.warn("Application file required. e.g.: julia AppSatellite.jl App.jl")
    return false
  end
  local stamp::Float64 = time()
  #
  # In case of error or if non zero exit code will be returned
  # an exeption will be thrown.
  #
  while true
    try
      while true
        run(`julia --color=yes $(ARGS[1]) recover $(ARGS[2:end])`)
        break
      end
      break
    catch e
      stamp = _removeBrokenBackup(stamp)
    end
  end

  true
end
#
# This is a fix for broken backup files. It's related to issue:
# https://github.com/JuliaLang/julia/issues/15017
# If app crashes less then BACKUP_PERIOD, then we have to remove last
# backup file, because it contains broken organisms code or somthing
# similar. The fact that we are inside this function means that our
# application has crashed a moment ago.
# @param stamp Timestamp of previous crash
# @return Updated last crash timestamp
#
function _removeBrokenBackup(stamp::Float64)
  local last::ASCIIString

  if (time() - stamp) < Float64(Config.val(:BACKUP_PERIOD)) * 60.0
    try
      if (last = Backup.lastFile()) != ""
        Helper.warn("Removing broken backup file: $last")
        rm(Backup.FOLDER_NAME * "/" * last)
      end
    catch e
      Helper.error("Something wrong with backup file removing: $last")
    end
    stamp = time()
  end

  stamp
end
#
# Application entry point
#
main()
