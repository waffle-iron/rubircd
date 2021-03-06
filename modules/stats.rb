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

require 'utility'

module Standard
  # Retrieves various statistics for a given server or current server if none is specified
  class Stats
    def initialize
      @command_name = 'stats'
      @command_proc = proc { |user, args| on_stats(user, args) }
    end

    def plugin_init(caller)
      caller.register_command(@command_name, @command_proc)
    end

    def plugin_finish(caller)
      caller.unregister_command(@command_name)
    end

    attr_reader :command_name

    # args[0] = symbol
    # args[1] = optional server
    def on_stats(user, args)
      args = args.join.split(' ', 2)
      unless user.operator || user.admin || user.service
        Network.send(user, Numeric.err_noprivileges(user.nick))
        return
      end
      if args.length < 1
        Network.send(user, Numeric.err_needmoreparams(user.nick, 'STATS'))
        return
      end
      # TODO: Handle optional server argument after linking is in a working state
      if args[0].length > 1 && args[0][0] == ':'
        args[0] = args[0][1]
      else
        args[0] = args[0][0]
      end
      case args[0]
      when 'c' # command statistics
        Command.command_counter_map.each { |key, value| Network.send(user, Numeric.rpl_statscommands(user.nick, key, value.command_count, value.command_recv_bytes)) }
      when 'd' # data transferred
        Network.send(user, Numeric.rpl_statsdebug(user.nick, format('%i bytes received', Server.data_recv)))
        Network.send(user, Numeric.rpl_statsdebug(user.nick, format('%i bytes sent', Server.data_sent)))
      when 'g' # glines
        # TODO: Coming in 0.3a
        # Uses numeric 223 (RPL_STATSGLINE)
      when 'i' # online admins and operators with idle times
        oper_count = 0
        Server.users.each do |u|
          if u.admin || u.operator || u.service
            Network.send(user, Numeric.rpl_statsdebug(user.nick, format('%s (%s) Idle: %i seconds', u.nick, u.hostname, (::Time.now.to_i - u.last_activity))))
            oper_count += 1
          end
        end
        Network.send(user, Numeric.rpl_statsdebug(user.nick, format('%i opers online', oper_count)))
      when 'k' # klines
        unless Server.kline_mod.nil?
          Server.kline_mod.list_klines.each { |kline| Network.send(user, Numeric.rpl_statskline(user.nick, kline.target, kline.create_time, kline.duration, kline.creator, kline.reason)) }
        end
      when 'l' # current client links
        Server.users.each { |u| Network.send(user, Numeric.rpl_statslinkinfo(user.nick, u)) }
      when 'm' # memory usage for certain data structures
      when 'o' # configured opers and admins
        Server.opers.each { |oper| Network.send(user, Numeric.rpl_statsoline(user.nick, oper.host, oper.nick, 'Operator')) }
        Server.admins.each { |admin| Network.send(user, Numeric.rpl_statsoline(user.nick, admin.host, admin.nick, 'Administrator')) }
      when 'p' # configured server ports
        if !Options.listen_host.nil?
          Network.send(user, Numeric.rpl_statsdebug(user.nick, format('%s:%i (plain)', Options.listen_host, Options.listen_port)))
          unless Options.ssl_port.nil?
            Network.send(user, Numeric.rpl_statsdebug(user.nick, format('%s:%i (SSL)', Options.listen_host, Options.ssl_port)))
          end
        else
          Network.send(user, Numeric.rpl_statsdebug(user.nick, format('0.0.0.0:%i (plain)', Options.listen_port)))
          if Network.ipv6_enabled
            Network.send(user, Numeric.rpl_statsdebug(user.nick, format(':::%i (plain)', Options.listen_port)))
          end
          unless Options.ssl_port.nil?
            Network.send(user, Numeric.rpl_statsdebug(user.nick, format('0.0.0.0:%i (SSL)', Options.ssl_port)))
            if Network.ipv6_enabled
              Network.send(user, Numeric.rpl_statsdebug(user.nick, format(':::%i (SSL)', Options.ssl_port)))
            end
          end
        end
      when 'q' # reserved nicks (qlines)
        unless Server.qline_mod.nil?
          Server.qline_mod.list_qlines.each { |qline| Network.send(user, Numeric.rpl_statsqline(user.nick, qline.target, qline.create_time, qline.duration, qline.creator, qline.reason)) }
        end
      when 's' # configured server links
        # TODO: Coming in 0.3a
        # Uses numerics 213 (RPL_STATSCLINE) and 244 (RPL_STATSHLINE)
      when 'u' # uptime
        days, hours, minutes, seconds = Utility.calculate_elapsed_time(Server.start_timestamp)
        Network.send(user, Numeric.rpl_statsuptime(user.nick, days, hours, minutes, seconds))
      when 'z' # zlines
        unless Server.zline_mod.nil?
          Server.zline_mod.list_zlines.each { |zline| Network.send(user, Numeric.rpl_statszline(user.nick, zline.target, zline.create_time, zline.duration, zline.creator, zline.reason)) }
        end
      end
      Network.send(user, Numeric.rpl_endofstats(user.nick, args[0]))
    end
  end
end
Standard::Stats.new
