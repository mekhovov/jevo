#
# TCP Client implementation. It works in pair with Server 
# module. It also works in asynchronous way (like a server) 
# and implements simple RPC-like logic. All you need to do is
# create a client, add listeners to EVENT_ANSWER event if needed 
# and call request() method as many times as needed. The answer 
# will be obtained through onAnswer() callback. 
# 
# It uses green threads (or coroutines) inside. See this link
# http://julia.readthedocs.org/en/latest/manual/control-flow/#man-tasks
# for more details regarding green threads. Comparing with 
# server, it has only one place, where "magic" occures. It's
# request() method. It uses tasks for sending non blocking 
# requests and obtaining answers (see @async macro in code).
# Every request creates one tasks 
#
# @author DeadbraiN
#
# See example below for details:
#
# TODO: check if this example work!!!
#     # This callback will be called as many times
#     # as many answers will be obtained from server.
#     function onAnswer(ans::Connection.Answer)
#       # do something with answer
#     end
#
#     # Creates the client and connects to server
#     connection = Client.create(ip"127.0.0.1", 2001)
#     # Starts to listen EVENT_ANSWER event
#     Event.on(connection.observer, EVENT_ANSWER, onAnswer)
#     # Makes a request to the server. An answer will
#     # be obtained in onAnswer() callback.
#     Client.request(connection, rand, 2, 3)
#
# Events:
#     answer{Connection.Answer} Answer object with data
#           obtained from server. May be empty.
# 
# @author DeadbraiN
# 
module Client
  import Connection
  import Event

  export create
  export request
  export stop
  export EVENT_ANSWER

  using Debug
  #
  # Name of the event, which is fired if answer from client's 
  # request is obtained.
  #
  const EVENT_ANSWER = "answer"
  #
  # Creates client and it's possibility to send requests to server.
  # In case of connection errors connection object will be created
  # in any case. You have to check this calling isopen() function.
  # @param host Host we are connecting to
  # @param port Port number we are connecting to
  # @return Client connection object
  #
  function create(host::Base.IpAddr, port::Integer)
    local sock::Base.TcpSocket
    local obs = Event.create()

    try
      sock = Base.connect(host, port)
      #
      # All "magic" occures here. This is how we start answers
      # handling. It listens clients responses all the time
      # using green thread (Task).
      #
      @async while true
        Event.fire(obs, EVENT_ANSWER, deserialize(sock))
      end
    catch e
      # TODO: what to do with e?
      close(sock)
    end

    Connection.ClientConnection(sock, obs)
  end
  #
  # Makes request to server. This method is not blocking. It returns
  # just after the call. Answer will be obtained in create() method
  # async loop.
  # @param con Connection object returned by create() method
  # @param fn Callback function id, which will be called if answer
  #           will be obtained from server.
  # @param args Custom fn arguments
  # @return true - request was sent, false wasn't
  #
  @debug function request(con::Connection.ClientConnection, fn::Integer, args...)
  @bp
    if !isopen(con.sock) return false end
    #
    # This line is non blocking one
    #
    serialize(con.sock, Connection.Command(fn, [i for i in args]))

    return true
  end
  #
  # Closes client's socket. After this call, we have to call create()
  # method again, if we want to send another request...
  # @param con Client's connection object, returned by create()
  #
  function stop(con::Connection.ClientConnection)
    #
    # TODO: i don't really know if julia GC removes our task
    # TODO: created inside create() method after closing 
    # TODO: connection. Need to check this...
    #
    close(con.sock)
  end
end