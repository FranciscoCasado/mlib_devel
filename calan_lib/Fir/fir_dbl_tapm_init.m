function fir_dbl_tapm_init(blk, varargin)

  defaults = {};
  check_mask_type(blk, 'fir_dbl_tapm');
  if same_state(blk, 'defaults', defaults, varargin{:}), return, end
  munge_block(blk, varargin{:});

  factor          = get_var('factor','defaults', defaults, varargin{:});
  add_latency     = get_var('latency','defaults', defaults, varargin{:});
  mult_latency    = get_var('latency','defaults', defaults, varargin{:});
  coeff_bit_width = get_var('coeff_bit_width','defaults', defaults, varargin{:});
  coeff_bin_pt    = get_var('coeff_bin_pt','defaults', defaults, varargin{:});

  delete_lines(blk);

  %default state in library
  if coeff_bit_width == 0,
    clean_blocks(blk);
    save_state(blk, 'defaults', defaults, varargin{:});  
    return; 
  end

  reuse_block(blk, 'a', 'built-in/Inport');
  set_param([blk,'/a'], ...
          'Port', '1', ...
          'Position', '[25 33 55 47]');

  reuse_block(blk, 'c', 'built-in/Inport');
  set_param([blk,'/c'], ...
          'Port', '2', ...
          'Position', '[25 213 55 227]');

  reuse_block(blk, 'Register0', 'xbsIndex_r4/Register');
  set_param([blk,'/Register0'], ...
          'Position', '[315 16 360 64]');

  reuse_block(blk, 'Register2', 'xbsIndex_r4/Register');
  set_param([blk,'/Register2'], ...
          'Position', '[315 196 360 244]');

  reuse_block(blk, 'coefficient', 'xbsIndex_r4/Constant');
  set_param([blk,'/coefficient'], ...
          'const', 'factor', ...
          'n_bits', 'coeff_bit_width', ...
          'bin_pt', 'coeff_bin_pt', ...
          'explicit_period', 'on', ...
          'Position', '[165 354 285 386]');

  reuse_block(blk, 'AddSub0', 'xbsIndex_r4/AddSub');
  set_param([blk,'/AddSub0'], ...
          'latency', 'add_latency', ...
          'arith_type', 'Signed  (2''s comp)', ...
          'n_bits', '18', ...
          'bin_pt', '16', ...
          'use_behavioral_HDL', 'on', ...
          'use_rpm', 'on', ...
          'Position', '[180 412 230 463]');

  reuse_block(blk, 'Mult0', 'xbsIndex_r4/Mult');
  set_param([blk,'/Mult0'], ...
          'n_bits', '18', ...
          'bin_pt', '17', ...
          'latency', 'mult_latency', ...
          'use_behavioral_HDL', 'on', ...
          'use_rpm', 'off', ...
          'placement_style', 'Rectangular shape', ...
          'Position', '[315 402 365 453]');

  reuse_block(blk, 'a_out', 'built-in/Outport');
  set_param([blk,'/a_out'], ...
          'Port', '1', ...
          'Position', '[390 33 420 47]');

  reuse_block(blk, 'c_out', 'built-in/Outport');
  set_param([blk,'/c_out'], ...
          'Port', '2', ...
          'Position', '[390 213 420 227]');

  reuse_block(blk, 'real', 'built-in/Outport');
  set_param([blk,'/real'], ...
          'Port', '3', ...
          'Position', '[390 423 420 437]');

  add_line(blk,'c/1','AddSub0/2', 'autorouting', 'on');
  add_line(blk,'c/1','Register2/1', 'autorouting', 'on');
  add_line(blk,'a/1','AddSub0/1', 'autorouting', 'on');
  add_line(blk,'a/1','Register0/1', 'autorouting', 'on');
  add_line(blk,'Register0/1','a_out/1', 'autorouting', 'on');
  add_line(blk,'Register2/1','c_out/1', 'autorouting', 'on');
  add_line(blk,'coefficient/1','Mult0/1', 'autorouting', 'on');
  add_line(blk,'AddSub0/1','Mult0/2', 'autorouting', 'on');
  add_line(blk,'Mult0/1','real/1', 'autorouting', 'on');
  
  % When finished drawing blocks and lines, remove all unused blocks.
  clean_blocks(blk);
  save_state(blk, 'defaults', defaults, varargin{:});

end % fir_dbl_tapm_init