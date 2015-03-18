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

module Optional
  class Userip
    def initialize()
      @command_name = "userip"
      @command_proc = Proc.new() { |user, args| on_userip(user, args) }
    end

    def plugin_init(caller)
      caller.register_command(@command_name, @command_proc)
    end

    def plugin_finish(caller)
      caller.unregister_command(@command_name)
    end

    def command_name
      @command_name
    end

    # args[0..-1] = nick or space-separated nicks
    def on_userip(user, args)
      # Unlike USERHOST, USERIP exposes the actual IP address of the user. As a
      # result, it requires elevated privileges in case host cloaking is enabled.
      unless user.is_operator? || user.is_admin? || user.is_service?
        Network.send(user, Numeric.ERR_NOPRIVILEGES(user.nick))
        return
      end
      if args.length < 1
        Network.send(user, Numeric.ERR_NEEDMOREPARAMS(user.nick, "USERIP"))
        return
      end
      args = args.join.split
      userip_list = []
      args.each do |a|
        if userip_list.length >= Limits::MAXTARGETS
          break
        end
        Server.users.each do |u|
          if u.nick.casecmp(a) == 0
            if u.is_admin? || u.is_operator?
              userip_list << "#{u.nick}*=+#{u.ident}@#{u.ip_address}"
            else
              userip_list << "#{u.nick}=+#{u.ident}@#{u.ip_address}"
            end
          end
        end
      end
      Network.send(user, Numeric.RPL_USERHOST(user.nick, userip_list))
    end
  end
end
Optional::Userip.new