require "./braintree"
require "option_parser"
require "file_utils"
require "ini"
require "colorize"

# TODO: singilton
# TODO: remote as a method
class Braintree::CLI
  enum Command
    None
    Banner
    Error
    TransactionFind
    DisputeAccept
    DisputeEvidence
    DisputeCreate
    DisputeFinalize
    DisputeFind
    DisputeSearch
    FileRead
    FileWrite
    FileDelete
    FileList
    FilePurge
    ConfigSetup
    ConfigShow
    ConfigUpdate
  end

  Log = ::Log.for("CLI")

  private property profile = "default"
  getter profile : String
  private property options = {} of Symbol => String
  getter options = {} of Symbol => String
  private property object_ids = [] of String
  getter object_ids = [] of String
  getter input_io : IO
  getter data_io : IO
  getter human_io : IO

  def initialize(@input_io = STDIN, @data_io = STDOUT, @human_io = STDERR)
  end

  def self.run
    CLI.new.run
  end

  def run
    banner = nil
    command = Command::Banner

    main_parser = OptionParser.parse do |parser|
      parser.banner = "Usage: bt [command] [switches]"
      parser.on("-h", "--help", "Prints this dialog") { banner = parser.to_s }
      parser.on("--version", "Print version") do
        command = Command::None
        human_io.puts Braintree::VERSION
      end
      parser.on("-v", "--verbose", "show debugging information") { ::Log.setup(:debug) }
      parser.on("-s", "--silent", "do not show human readable output") { setup_null_output }
      parser.on("-p", "--profile", "profile") { |_p| profile = _p }

      parser.separator("Subcommands")
      parser.on("data", "Data subcommands") do
        parser.on("-R", "--read", "reads the file with ID") { command = Command::FileRead }
        parser.on("-W DATA", "--write DATA", "writes the file with ID") do |_d|
          command = Command::FileWrite
          options[:data] = _d
        end
        parser.on("-D", "--delete", "deletes the file with ID") { command = Command::FileDelete }
        parser.on("-L", "--list", "lists all data files") { command = Command::FileList }
        parser.on("-P", "--purge", "purges all data files") { command = Command::FilePurge }

        parser.unknown_args do |pre_dash, post_dash|
          Log.debug { "File IDs pre: #{pre_dash}, post: #{post_dash}" }

          if !pre_dash.empty? || !post_dash.empty?
            command = Command::FileRead if command == Command::Banner
            object_ids.concat(pre_dash)
          end

          if !input_tty?
            ARGF.each_line do |line|
              human_io.puts "Ingested Data: #{line}"
              object_ids << line.split(ENV.fetch("FS", " "))[0]
            end
          end

          command = Command::DisputeFind if command == Command::Banner if 0 < object_ids.size
        end
      end

      parser.on("config", "Configuration subcommands") do
        parser.banner = "Usage: bt dispute create [switches]"
        parser.on("setup", "initial setup of configuration") { command = Command::ConfigSetup }
        parser.on("-e", "--show-enviroment", "Shows enviroment") {
          command = Command::ConfigShow
          options[:enviroment] = "show"
        }
        parser.on("-E ENV", "--enviroment ENV", "Set enviroment") { |_k|
          command = Command::ConfigUpdate
          options[:enviroment] = _k
        }
        parser.on("-u", "--show-host", "Shows host") {
          command = Command::ConfigShow
          options[:host] = "show"
        }
        parser.on("-U HOST", "--host HOST", "Set host") { |_k|
          command = Command::ConfigUpdate
          options[:host] = _k
        }
        parser.on("-m", "--show-merchant-id", "Show merchant id") {
          command = Command::ConfigShow
          options[:merchant] = "show"
        }
        parser.on("-M MID", "--merchant_id MID", "Set merchant id") { |_m|
          command = Command::ConfigUpdate
          options[:merchant] = _m
        }
        parser.on("-k", "--show-public_key", "Shows public key") {
          command = Command::ConfigShow
          options[:public_key] = "show"
        }
        parser.on("-K KEY", "--public_key KEY", "Set public key") { |_k|
          command = Command::ConfigUpdate
          options[:public_key] = _k
        }
        parser.on("-q", "--show_private_key", "Shows private key") {
          command = Command::ConfigShow
          options[:private_key] = "show"
        }
        parser.on("-Q KEY", "--private_key KEY", "Set private key") { |_k|
          command = Command::ConfigUpdate
          options[:private_key] = _k
        }
      end

      parser.on("transaction", "Transaction subcommands") do
        parser.unknown_args do |pre_dash, post_dash|
          Log.debug { "Transaction IDs pre: #{pre_dash}, post: #{post_dash}" }

          if !pre_dash.empty? || !post_dash.empty?
            command = Command::TransactionFind if command == Command::Banner
            object_ids.concat(pre_dash)
          end

          if !input_tty?
            ARGF.each_line do |line|
              human_io.puts "Ingested Transaction: #{line}"
              object_ids << line.split(ENV.fetch("FS", " "))[0]
            end
          end

          command = Command::DisputeFind if command == Command::Banner if 0 < object_ids.size
        end
      end

      parser.on("dispute", "Dispute subcommands") do
        parser.banner = "Usage: bt dispute [subcommand|ids] [switches]"
        parser.on("-h", "--help", "Prints this dialog") {
          command = Command::Banner
          banner = parser.to_s
        }
        parser.separator("Global")
        parser.on("-l", "--local", "persist/use local data") { options[:source] = "local" }
        parser.on("-r", "--remote", "only use remote date") { options[:source] = "remote" }
        parser.on("-X", "--expand", "show expanded information") { options[:data] = "expanded" }
        parser.separator("Actions")
        parser.on("-F", "--finalize", "finalizes the dispute") { command = Command::DisputeFinalize }
        parser.on("-A", "--accept", "accepts a dispute") { command = Command::DisputeAccept }

        parser.separator("Subcommands")
        parser.on("create", "create a new dispute") do
          # TODO: create a fail fast option
          command = Command::DisputeCreate
          parser.banner = "Usage: bt dispute create [switches]"
          parser.on("-h", "--help", "Prints this dialog") {
            command = Command::Banner
            banner = parser.to_s
          }
          parser.on("-n NUM", "--number NUM", "number of disputes to create") { |_n| options[:number] = _n }
          parser.separator("Attributes")
          parser.on("-a AMOUNT", "--amount AMOUNT", "set amount for dispute") { |_a| options[:amount] = _a }
          parser.on("-c CC_NUM", "--credit_card CC_NUM", "set card number for dispute") { |_c| options[:card_number] = _c }
          parser.on("-e DATE", "--exp_date DATE", "set expiration date for dispute") { |_e| options[:exp_date] = _e }
          parser.on("-S STATUS", "--status STATUS", "set expiration date for dispute (open,won,lost)") { |_s| options[:status] = _s }
        end

        parser.on("evidence", "adds file evidence") do
          command = Command::DisputeEvidence
          parser.on("-h", "--help", "Prints this dialog") {
            command = Command::Banner
            banner = parser.to_s
          }
          parser.separator("Types")
          parser.on("-t TEXT", "--text TEXT", "adds text evidenxe") { |_t| options[:text] = _t }
          parser.on("-f PATH", "--file PATH", "path to file") { |_f| options[:file] = _f }
          parser.on("-r ID", "--remove ID", "removes evidence for dispute") { |_id| options[:remove] = _id }
        end

        parser.on("search", "searches disputes") do
          command = Command::DisputeSearch
          parser.on("-h", "--help", "Prints this dialog") {
            command = Command::Banner
            banner = parser.to_s
          }
          parser.on("-X", "--expanded", "includeds transaction data") { options[:data] = "expanded" }
          parser.separator("Pagination")
          parser.on("-p NUM", "--page_num NUM", "results page number") { |_p| options[:page_num] = _p }
          parser.on("-A", "--all", "gets all results") { options[:all] = "all" }
          parser.separator("Search Criteria")
          parser.on("-a AMOUNTS", "--disputed AMOUNTS", "amount disputed range (100,200)") { |_a| options[:amount_disputed] = _a }
          parser.on("-w AMOUNTS", "--won AMOUNTS", "amount won range (100,200)") { |_a| options[:amount_won] = _a }
          parser.on("-c NUM", "--case NUM", "case number") { |_c| options[:case_number] = _c }
          parser.on("-C ID", "--customer ID", "customer id") { |_c| options[:customer_id] = _c }
          parser.on("-d DATE", "--disbursement DATE", "disbursement date (7/1/2020,10/1/2020)") { |_d| options[:disbursement_date] = _d }
          parser.on("-e DATE", "--effective DATE", "effective date (7/1/2020,10/1/2020)") { |_e| options[:effective_date] = _e }
          parser.on("-i ID", "--id ID", "dispute id") { |_i| options[:dispute_id] = _i }
          parser.on("-k KIND", "--kind KIND", "kind (chargeback,retrieval)") { |_k| options[:kind] = options[:kind]? ? "#{options[:kind]},#{_k}" : _k }
          parser.on("-m ID", "--merchant_account_id ID", "merchant account id") { |_k| options[:merchant_account_id] = _k }
          parser.on("-r REASON", "--reason REASON", "reason") { |_r| options[:reason] = _r }
          parser.on("-R CODE", "--reason_code CODE", "reason_code (83,84,85)") { |_r| options[:reason_code] = _r }
          parser.on("-D DATE", "--received DATE", "received date (7/1/2020,10/1/2020)") { |_r| options[:received_date] = _r }
          parser.on("-n NUM", "--reference_number NUM", "reference number") { |_r| options[:reference_number] = _r }
          parser.on("-b DATE", "--reply_by DATE", "reply by date") { |_r| options[:reply_by_date] = _r }
          parser.on("-t ID", "--tx_id ID", "transaction id") { |_t| options[:transaction_id] = _t }
          parser.on("-S STATUS", "--status STATUS", "status (open,won,lost)") { |_s| options[:status] = options[:status]? ? "#{options[:status]},#{_s}" : _s }
          parser.on("-T SOURCE", "--tx_source SOURCE", "transaction source (api,control_panel,recurring)") { |_t| options[:transaction_source] = _t }
        end

        parser.unknown_args do |pre_dash, post_dash|
          Log.debug { "Dispute IDs pre: #{pre_dash}, post: #{post_dash}" }

          if !pre_dash.empty? || !post_dash.empty?
            command = Command::DisputeFind if command == Command::Banner
            object_ids.concat(pre_dash)
          end

          if !input_tty?
            ARGF.each_line do |line|
              human_io.puts "Ingested Dispute: #{line}"
              object_ids << line.split(ENV.fetch("FS", " "))[0]
            end
          end

          command = Command::DisputeFind if command == Command::Banner if 0 < object_ids.size
        end
      end

      parser.invalid_option do |flag|
        command = Command::Error
        human_io.puts "ERROR: #{flag} is not a valid option."
        human_io.puts parser
      end
    end
    banner ||= main_parser.to_s

    Log.debug { "profile: #{profile}" }
    Log.debug { "command: #{command}" }
    Log.debug { "options: #{options}" }
    Log.debug { "object_ids: #{object_ids}" }

    case command
    when Command::None
      exit
    when Command::Banner
      human_io.puts banner
      exit
    when Command::Error
      exit 1
    when Command::FileRead
      FileReadCommand.run(self)
    when Command::FileWrite
      FileWriteCommand.run(self)
    when Command::FileDelete
      FileDeleteCommand.run(self)
    when Command::FileList
      FileListCommand.run(self)
    when Command::ConfigShow
      Config::ShowCommand.run(self)
    when Command::ConfigUpdate
      Config::UpdateCommand.run(self)
    when Command::ConfigSetup
      config.setup
    when Command::FilePurge
      FilePurgeCommand.run(self)
    when Command::TransactionFind
      Transaction::FindCommand.run(self)
    when Command::DisputeAccept
      Dispute::AcceptCommand.run(self)
    when Command::DisputeEvidence
      Dispute::EvidenceCommand.run(self)
    when Command::DisputeCreate
      Dispute::CreateCommand.run(self)
    when Command::DisputeFinalize
      Dispute::FinalizeCommand.run(self)
    when Command::DisputeFind
      Dispute::FindCommand.run(self)
    when Command::DisputeSearch
      Dispute::SearchCommand.run(self)
    else
      human_io.puts "ERROR: you found an error in the CLI please consider submitting an issue"
      exit 1
    end
  end

  def setup_null_output
    @human_io = File.open(File::NULL, "w")
  end

  def color?
    error.tty?
  end

  def input_tty?
    input_io.tty?
  end

  def human_tty?
    human_io.tty?
  end

  def data_tty?
    data_io.tty?
  end

  def config
    BT.config(profile)
  end
end

require "./cli/**"

Log.setup_from_env(default_level: :error)
BT::CLI.run
