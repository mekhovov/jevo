# Server
tasks  = Task[]
socks  = Base.TcpSocket[]
server = listen(2001)
index  = 1

task = @async begin
	while true
	    push!(socks, accept(server))
	    index = length(socks)
	    push!(tasks, @async while isopen(socks[index])
			write(socks[index], readline(socks[index]))
	    end)
	end
end

function updateSockets()
	#consume(task)
	for t = 1:length(tasks)
	    if !isopen(socks[t])
	    	deleteat!(tasks, t)
	    	deleteat!(socks, t)
	    end

	    #index = t
		#consume(tasks[t])
	end
end