#
# Manages organisms and they world
#
# @singleton
# @author DeadbraiN
#
# TODO: describe included files and how to split Manager on files.
# TODO:   - Manager may call every function from any file
# TODO:   - File may call every function except other files
# TODO:   - If file calls Manager function it hould add Manager. before calling
# TODO: describe that manager is a mediator between all other objects
# TODO: like world, terminal and so on.
# TODO: add remote functions for changing period and probs
# TODO: add command line parameter for creating default config file
# TODO: add create method. It should return ManagerData() type
# TODO: describe frozen organisms conception
#
module Manager
  import CodeConfig.@if_status
  import CodeConfig.@if_debug
  import CodeConfig.@if_test
  import CodeConfig.@if_profile
  import CodeConfig
  import Creature
  import Mutator
  import World
  import Helper
  import Event
  import Server
  import Client
  import Connection
  import CommandLine
  import RpcApi
  import FastApi
  import Config
  import ManagerTypes

  export create
  export run
  export destroy
  #
  # This is how we collect Manager module from it's parts(files)
  #
  include("ManagerOrganism.jl")
  include("ManagerRpc.jl")
  include("ManagerBackup.jl")
  include("ManagerParams.jl")
  @if_status include("ManagerStatus.jl")
  #
  # Creates manager related data instance. It will be passed to all
  # manager methods. ManagerStatus type will be created in any case.
  # In case if CodeConfig.modeStatus set in true or false. This is
  # because i don't know how exclude one field from type depending
  # on CodeConfig.modeStatus parameters. May be some cool macro may
  # do it, maybe...
  # @param cfg Configuration object for manager
  #
  function create(cfg::Config.ConfigData = Config.create())
    local man::ManagerTypes.ManagerData = ManagerTypes.ManagerData(
      cfg,                                                                      # cfg
      World.create(cfg.WORLD_WIDTH, cfg.WORLD_HEIGHT),                          # world
      Dict{Int, Creature.Organism}(),                                           # positions
      Dict{UInt, Creature.Organism}(),                                          # organisms
      ManagerTypes.OrganismTask[],                                              # tasks
      CommandLine.create(),                                                     # params
      UInt(1),                                                                  # organismId
      UInt(0),                                                                  # totalOrganisms
      CommandLine.has(CommandLine.create(), ARG_QUIET),                         # quiet
      function() end,                                                           # dotCallback
      function() end,                                                           # moveCallback
      current_task(),                                                           # task
      ManagerTypes.ManagerStatus(0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0)                # status
    )
    local cons::ManagerTypes.Connections = _createConnections(man)

    man.cons = cons
    man
  end
  #
  # Runs Manager instance, one world, server an so on... Blocking
  # function.
  # @param man Manager data type
  # @param recover true if we have to recover from last backup
  # @return {Bool} run status
  #
  function run(man::ManagerTypes.ManagerData, recover::Bool = false)
    #
    # must be started from 1! because we use % (div reminder) for checking
    # if some config related to iterations occures. In case of 0 value
    # all configs will be run at the beginning.
    #
    local counter   ::Int = 1
    local ips       ::Int = 0
    local istamp    ::Float64 = time()
    local bstamp    ::Float64 = istamp
    local ystamp    ::Float64 = istamp
    local cons      ::ManagerTypes.Connections = man.cons
    local tasks     ::Array{ManagerTypes.OrganismTask, 1} = man.tasks
    local cfg       ::Config.ConfigData = man.cfg
    local needYield ::Bool = false
    local backups   ::Int  = 0
    local needExit  ::Bool = false
    @if_profile local i::Int = 0

    try
      #
      # This server is listening for all other managers and remote
      # terminal. It runs obtained commands and send answers back.
      # In other words, it works like RPC runner... Fast server is
      # listening for "fast" clients and works in "fast" mode.
      #
      Server.run(man.cons.server)
      # TODO: possibly, we don't need to run this server due to performance issue
      Server.run(man.cons.fastServer)
      #
      # If user set up some amount of organisms they will be created
      # in this call. If we are in recover mode, then this step should
      # be skipped.
      #
      if !recover
        if cfg.WORLD_START_ENERGY_BLOCKS + cfg.WORLD_START_ENERGY_AMOUNT > 0
          setRandomEnergy(man, cfg.WORLD_START_ENERGY_BLOCKS, cfg.WORLD_START_ENERGY_AMOUNT)
        end
        if man.cfg.ORGANISM_START_AMOUNT > 0 createOrganisms(man) end
      end
      #
      # This is main infinite loop. It manages input connections
      # and organism's tasks switching.
      #
      while true
        #
        # We have to wait while all clients are ready for streaming. This
        # is because the error in serializer. See issue for details:
        # https://github.com/JuliaLang/julia/issues/16746
        #
        if cons.streamInit yield(); @if_status man.status.yps += 1; continue end
        #
        # This is global time stamp in seconds
        #
        stamp = time()
        #
        # This call runs all organism related tasks one by one
        #
        counter = _updateOrganisms(man, counter, needYield)
        #
        # We have to update IPS (Iterations Per Second) every second
        #
        ips, istamp = _updateIps(man, ips, stamp, istamp)
        #
        # This call switches between all non blocking asynchronous
        # functions (see @async macro). For example, it handles all
        # input connections for current server. But we don't need to
        # call yield() every time, because it eats CPU cicles. We
        # have to wait some period and call yield() to check if
        # sockets have data.
        # TODO: this code may be optimized. We already call yield()
        # TODO: in _onDot() handler. Second idea, that we have to use
        # TODO: yieldto(), because we know all network related tasks
        # TODO: created by @async() macro.
        ystamp, needYield = _updateTasks(man, stamp, ystamp, needYield)
        #
        # Here we make auto-backup of application if there is a time
        #
        bstamp, backups, needExit = _updateBackup(man, stamp, bstamp, backups)
        if needExit return false end
        #
        # It's important to skip this function if CodeConfig.showStatus
        # flag is set to false. See CodeConfig::showStatus for details.
        #
        @if_status _updateStatus(man, stamp)
        #
        # This code is used for profiling of jevo
        #
        @if_profile if (i += 1) > CodeConfig.modeProfilePeriod return true end
        #
        # This line is for special testing mode, which is called "iterational".
        # In this mode we may run Manager iteration by iteration and measure
        # different parameters like amount of organisms or their energy. It's
        # easier to write unit tests with such mode...
        #
        @if_test produce(counter)
      end
    catch e
      Helper.error("Manager.run(): $e")
      @if_debug showerror(STDOUT, e, catch_backtrace())
      return false
    end
    #
    # true means, that everything is okay, false - something went wrong
    #
    true
  end
  #
  # Destroys the manager and all realted components like servers,
  # clients, etc...
  # @param man Manager data object
  #
  function destroy(man::ManagerTypes.ManagerData)
    World.destroy(man.world)
    Server.stop(man.cons.server)
    Server.stop(man.cons.fastServer)
    Client.stop(man.cons.left)
    Client.stop(man.cons.right)
    Client.stop(man.cons.up)
    Client.stop(man.cons.down)

    man.positions    = Dict{Int, Creature.Organism}()
    man.organisms    = Dict{UInt, Creature.Organism}()
    man.tasks        = []
    man.params       = Dict{String, String}()
    man.dotCallback  = Helper.emptyFn
    man.moveCallback = Helper.emptyFn
    man.cons.frozen  = Dict{UInt, Creature.Organism}()
  end
  #
  # This is how we stop the task. Stop means run last yieldto()
  # inside the task, but not more. Otherwise it will stuck inside
  # the task forever. This method only marks the task as
  # "deleted". Real deletion will be provided in _updateOrganismsEnergy().
  # @param task Task
  # TODO: do we need this?
  function stopTask(task::Task)
    #try Base.throwto(task, InterruptException()) end
    #task.state = :failed
  end

  #
  # Generates unique id by world position. This macro is
  # private insode Manager module
  # @param man Manager data type
  # @param {Helper.Point} pos Unique World position
  # @return {Int} Unique pos id
  #
  function _getPosId(man::ManagerTypes.ManagerData, pos::Helper.Point) pos.y * man.world.width + pos.x end
  #
  # Checks if specified position in a world is free. Other organism
  # or an energy block may be there at the moment.
  # @param pos Position we need to check
  # @return {Bool} true - free point, false - filled point
  # TODO: this method is very slow!!!
  function _isFree(man::ManagerTypes.ManagerData, pos::Helper.Point)
    !haskey(man.positions, _getPosId(man, pos)) && World.getEnergy(man.world, pos) === UInt32(0)
  end
  #
  # Updates IPS (Iterations Per second) counter and stores it in config
  # @param man Manager data type
  # @param ips IPS
  # @param stamp Current UNIX time stamp value
  # @param istamp IPS last UNIX time stamp value
  # @return {Int, Int} new ips and current UNIX time stamp
  #
  function _updateIps(man::ManagerTypes.ManagerData, ips::Int, stamp::Float64, istamp::Float64)
    local ts::Float64 = stamp - istamp
    local sock::Base.TCPSocket
    local dataIndex::UInt8
    local localIps::Int
    # TODO: 1.0 seconds should be get from config
    if ts >= 1.0
      localIps  = trunc(Int, ips / ts)
      dataIndex = UInt8(FastApi.API_UINT64)
      man.cfg.WORLD_IPS = localIps
      @inbounds for sock in man.cons.fastServer.socks
        if Helper.isopen(sock)
          Server.request(sock, dataIndex, localIps)
          @if_status man.status.rps += 1
        end
      end
      return 0, stamp
    end

    ips + 1, istamp
  end
  #
  # Checks if it's a time to make application backup. It also checks if
  # system reaches specified amount of backups for app reset.
  # @param man Manager data type
  # @param stamp Current UNIX timestamp
  # @param bstamp Backup last UNIX time stamp value
  # @param backups Amount of backups from previous app reset
  # @return {(Float64, Bool)} Updated time stamp and main loop quit flag
  #
  function _updateBackup(man::ManagerTypes.ManagerData, stamp::Float64, bstamp::Float64, backups::Int)
    if stamp - bstamp >= man.cfg.BACKUP_PERIOD
      if length(man.tasks) > 0
        backup(man)
        backups += 1
        if backups === man.cfg.WORLD_RESET_AFTER_BACKUPS return (stamp, backups, true) end
      end
      return (stamp, backups, false)
    end

    (bstamp, backups, false)
  end
  # TODO: describe yield() call logic
  # Checks if active servers have bytes to read. It means, that we have to call
  # yield() for this reading. yield() function will be called in organisms
  # loop in ManagerOrganism.jl file.
  # @param man Manager data type
  # @param stamp Current UNIX time stamp
  # @param ystamp yield last UNIX time stamp
  # @param needYield Flag if we need for yield() call
  # @return {(Float64, Bool)}
  #
  function _updateTasks(man::ManagerTypes.ManagerData, stamp::Float64, ystamp::Float64, needYield::Bool)
    if stamp - ystamp >= man.cfg.CONNECTION_TASKS_CHECK_PERIOD
      yield()
      @if_status man.status.yps += 1
      # TODO: potential problem here. this list of sockets may be expanded
      # TODO: for example in many managers mode
      return stamp, (length(man.cons.server.socks) > 0 || man.cons.streamInit)
    end

    ystamp, needYield
  end
  #
  # Updates organism's task by creating new task with passed parameters
  # @param man Instamce of ManagerData type
  # @param task OrganismTask instance, where we have to update the task
  #
  function _updateOrgTask(man::ManagerTypes.ManagerData, task::ManagerTypes.OrganismTask)
    task.task = Task(() -> Creature.born(task.organism, man.cfg, man.task))
    #yieldto(task.task)
    #@if_status man.status.ytps += 1
  end
  # # TODO: do i need this?
  # # Checks id data in sockets available for reading
  # # @param man Manager data type
  # # @return {Bool}
  # #
  # function _dataAvailable(man::ManagerTypes.ManagerData)
  #   local cons::ManagerTypes.Connections = man.cons
  #   local sock::Base.TCPSocket
  #
  #   @inbounds for sock in cons.server.socks
  #     if nb_available(sock) > 0 return true end
  #   end
  #   if cons.streamInit
  #     @inbounds for sock in cons.fastServer.socks
  #       if nb_available(sock) > 0 return true end
  #     end
  #   end
  #
  #   false
  # end
end
