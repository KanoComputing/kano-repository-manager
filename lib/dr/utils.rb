# Copyright (C) 2014 Kano Computing Ltd.
# License: http://www.gnu.org/licenses/gpl-2.0.txt GNU General Public License v2

module Dr
  module Utils
    def self.symbolise_keys(hash)
      if hash.is_a? Hash
        hash.inject({}) do |new_hash, (key, value)|
          new_hash[key.to_sym] = symbolise_keys value
          new_hash
        end
      else
        hash
      end
    end

    def self.stringify_keys(hash)
      return hash unless hash.is_a? Hash

      hash.inject({}) do |new_hash, (key, value)|
        new_hash[key.to_s] = stringify_keys value
        new_hash
      end
    end

    def self.stringify_symbols(var)
      case
        when var.is_a?(Hash)
          var.inject({}) do |new_hash, (key, value)|
            new_hash[key.to_s] = stringify_keys value
            new_hash
          end
        when var.is_a?(Array)
          var.map {|e| stringify_symbols e}
        when var.is_a?(Symbol)
          var.to_s
        else
          var
      end
    end
  end
end
