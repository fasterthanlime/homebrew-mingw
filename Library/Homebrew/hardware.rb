class Hardware
  # These methods use info spewed out by sysctl.
  # Look in <mach/machine.h> for decoding info.

  def self.cpu_type
    # TODO: support other CPU types?
    :intel
  end

  def self.intel_family
    # TODO: find which 'wmic cpu get Family' codes correspond to which actual family
    :dunno
  end

  def self.processor_count
    @@processor_count ||= `wmic cpu get NumberOfLogicalProcessors | tail -2 | head -1`.to_i
  end
  
  def self.cores_as_words
    case Hardware.processor_count
    when 1 then 'single'
    when 2 then 'dual'
    when 4 then 'quad'
    else
      Hardware.processor_count
    end
  end

  def self.is_32_bit?
    not self.is_64_bit?
  end

  def self.is_64_bit?
    return @@is_64_bit if defined? @@is_64_bit
    @@is_64_bit = `wmic cpu get AddressWidth | tail -2 | head -1`.to_i == 64
  end
  
  def self.bits
    Hardware.is_64_bit? ? 64 : 32
  end
end
