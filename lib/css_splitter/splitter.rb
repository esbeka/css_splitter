module CssSplitter

  class Splitter

    MAX_SELECTORS_DEFAULT = 4095

    # returns the specified split of the passed css_string
    def self.split_string(css_string, split = 1, max_selectors = MAX_SELECTORS_DEFAULT)
      rules = split_string_into_rules(css_string)
      extract_part rules, split, max_selectors
    end

    # splits string into array of rules (also strips comments)
    def self.split_string_into_rules(css_string)
      strip_comments(css_string).chomp.scan /[^}]*}/
    end

    # extracts the specified part of an overlong CSS string
    def self.extract_part(rules, part = 1, max_selectors = MAX_SELECTORS_DEFAULT)
      return if rules.first.nil?

      charset_statement, rules[0] = extract_charset(rules.first)
      return if rules.nil?

      output = charset_statement || ""
      selectors_count = 0
      selector_range = max_selectors * (part - 1) + 1 .. max_selectors * part # e.g (4096..8190)

      current_media = nil
      first_hit = true
      rules.each do |rule|
        media_part = extract_media!(rule)
        if media_part
          current_media = media_part
        elsif rule =~ /^\s*}$/
          current_media = nil
        end

        rule_selectors_count = count_selectors_of_rule rule
        selectors_count += rule_selectors_count

        if selector_range.cover? selectors_count # add rule to current output if within selector_range
          next if first_hit and rule =~ /^\s*}$/ # skip the line if the close bracket is the first rule for the new file
          if media_part
            output << media_part
          elsif first_hit && current_media
            output << current_media
          end
          output << rule
          first_hit = false
        elsif selectors_count > selector_range.end # stop writing to output
          puts ""
          puts "NOTE: If you haven't created a split#{part+1} file yet, you need to do so now."
          puts "Split#{part} has reached the limit of #{MAX_SELECTORS_DEFAULT} while trying to add #{selectors_count} selectors."
          puts ""
          break
        end
      end

      if current_media
        output << '}'
      end

      output
    end

    def self.extract_media!(rule)
      if rule.sub!(/^\s*(@media[^{]*{)([^{}]*{[^}]*})$/) { $2 }
        $1
      end
    end

    # count selectors of one individual CSS rule
    def self.count_selectors_of_rule(rule)
      strip_comments(rule).partition(/\{/).first.scan(/,/).count.to_i + 1
    end



    # count selectors of a CSS stylesheet (not used by SprocketsEngine)
    def self.count_selectors(css_file)
      raise "file could not be found" unless File.exists? css_file

      rules = split_string_into_rules(File.read css_file)
      return if rules.first.nil?

      rules.sum{ |rule| count_selectors_of_rule(rule) }
    end



    private

      # extracts potential charset declaration from the first rule
      def self.extract_charset(rule)
        if rule.include?('charset')
          rule.partition(/^\@charset[^;]+;/)[1,2]
        else
          [nil, rule]
        end
      end

      def self.strip_comments(s)
        s.gsub(/\/\*.*?\*\//m, "")
      end

  end

end
