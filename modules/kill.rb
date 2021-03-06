# RubIRCd - An IRC server written in Ruby
# Copyright (C) 2013 Lloyd Dilley (see authors.txt for details)
# http://www.rubircd.rocks/
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

module Standard
  # Removes a user from the network with optional reason
  # Use is limited to administrators and IRC operators
  class Kill
    def initialize
      @command_name = 'kill'
      @command_proc = proc { |user, args| on_kill(user, args) }
    end

    def plugin_init(caller)
      caller.register_command(@command_name, @command_proc)
    end

    def plugin_finish(caller)
      caller.unregister_command(@command_name)
    end

    attr_reader :command_name

    # args[0] = target nick
    # args[1] = message
    def on_kill(user, args)
      args = args.join.split(' ', 2)
      unless user.operator || user.admin || user.service
        Network.send(user, Numeric.err_noprivileges(user.nick))
        return
      end
      if args.length < 1
        Network.send(user, Numeric.err_needmoreparams(user.nick, 'KILL'))
        return
      end
      if args.length == 2
        args[1] = args[1][1..-1] if args[1][0] == ':' # remove leading ':'
      else
        args[1] = 'No reason given'
      end
      kill_target = nil
      Server.users.each { |u| kill_target = u if u.nick.casecmp(args[0]) == 0 }
      if kill_target.nil?
        Network.send(user, Numeric.err_nosuchnick(user.nick, args[0]))
        return
      else
        Server.users.each do |u|
          if u.umodes.include?('s')
            Network.send(u, ":#{Options.server_name} NOTICE #{u.nick} :*** BROADCAST: #{user.nick} has issued a KILL for #{kill_target.nick}: #{args[1]}")
          end
        end
        if (kill_target.admin && !user.admin) || kill_target.service
          Network.send(user, Numeric.err_attackdeny(user.nick, kill_target.nick))
          if kill_target.admin
            Network.send(kill_target, ":#{Options.server_name} NOTICE #{kill_target.nick} :#{user.nick} attempted to kill you!")
          end
          return
        end
        Network.send(kill_target, ":#{user.nick}!#{user.ident}@#{user.hostname} KILL #{kill_target.nick} :#{Options.server_name}!#{user.hostname}!#{user.nick} (#{args[1]})")
        Network.send(kill_target, "ERROR :Closing link: #{kill_target.hostname} [Killed (#{user.nick} (#{args[1]}))]")
        Log.write(2, "#{kill_target.nick}!#{kill_target.ident}@#{kill_target.hostname} was killed by #{user.nick}!#{user.ident}@#{user.hostname}: #{args[1]}")
        Network.close(kill_target, "Killed (#{user.nick} (#{args[1]}))", false)
      end
    end
  end
end
Standard::Kill.new
