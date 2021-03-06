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
  # Kicks a target nick or group of comma-separated nicks from the specified channel
  # with optional reason
  class Kick
    def initialize
      @command_name = 'kick'
      @command_proc = proc { |user, args| on_kick(user, args) }
    end

    def plugin_init(caller)
      caller.register_command(@command_name, @command_proc)
    end

    def plugin_finish(caller)
      caller.unregister_command(@command_name)
    end

    attr_reader :command_name

    # args[0] = channel
    # args[1] = user or comma-separated users
    # args[2] = optional reason
    def on_kick(user, args)
      args = args.join.split(' ', 3)
      if args.length < 2
        Network.send(user, Numeric.err_needmoreparams(user.nick, 'KICK'))
        return
      end
      chan = Server.channel_map[args[0].to_s.upcase]
      if chan.nil?
        Network.send(user, Numeric.err_nosuchchannel(user.nick, args[0]))
        return
      end
      unless user.on_channel?(chan.name)
        Network.send(user, Numeric.err_notonchannel(user.nick, args[0]))
        return
      end
      if !user.chanop?(chan.name) && !user.admin && !user.service
        Network.send(user, Numeric.err_chanoprivsneeded(user.nick, chan.name))
        return
      end
      nicks = args[1].split(',')
      if args.length == 3
        args[2] = args[2][1..-1] if args[2][0] == ':' # remove leading ':'
        args[2] = args[2][0..Limits::KICKLEN - 1] if args[2].length > Limits::KICKLEN
      end
      good_nicks = []
      kick_count = 0
      nicks.each do |n|
        if Server.users.any? { |u| u.nick.casecmp(n) == 0 }
          good_nicks << n
        else
          Network.send(user, Numeric.err_nosuchnick(user.nick, n))
        end
      end
      good_nicks.each do |n|
        Server.users.each do |u|
          next unless u.nick.casecmp(n) == 0
          if !u.on_channel?(chan.name)
            Network.send(user, Numeric.err_usernotinchannel(user.nick, u.nick, chan.name))
          elsif (u.admin && !user.admin) || u.service
            Network.send(user, Numeric.err_attackdeny(user.nick, u.nick))
            if u.admin
              Network.send(u, ":#{Options.server_name} NOTICE #{u.nick} :#{user.nick} attempted to kick you from #{chan.name}")
            end
          elsif kick_count >= Limits::MODES
            Network.send(user, Numeric.err_toomanytargets(user.nick, u.nick))
            next unless u.nil?
          else
            if !args[2].nil?
              chan.users.each { |cu| Network.send(cu, ":#{user.nick}!#{user.ident}@#{user.hostname} KICK #{chan.name} #{u.nick} :#{args[2]}") }
            else
              chan.users.each { |cu| Network.send(cu, ":#{user.nick}!#{user.ident}@#{user.hostname} KICK #{chan.name} #{u.nick}") }
            end
            kick_count += 1
            chan.remove_user(u)
            u.remove_channel(chan.name)
            unless chan.users.length > 0 || chan.registered
              Server.remove_channel(chan)
            end
          end
        end
      end
    end
  end
end
Standard::Kick.new
