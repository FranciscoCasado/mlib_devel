function filt_simple_init(blk,varargin)

clog('entering filt_simple_init', 'trace');

% Declare any default values for arguments you might like.
% Added defaults and fixed the quatization default for 10.1 tools AWL
defaults = {'n_inputs', 1, 'n_bits', 8, ...
    'coeff', 0.1, ...
    'quantization', 'Round  (unbiased: +/- Inf)', ...
    'add_latency', 1, 'mult_latency', 2, 'conv_latency', 2, ...
    'coeff_bit_width', 25, 'coeff_bin_pt', 24, ...
    'absorb_adders', 'on', 'adder_imp', 'DSP48'};

check_mask_type(blk, 'filt_simple');

if same_state(blk, 'defaults', defaults, varargin{:}), return, end
clog('filt_simple_init post same_state', 'trace');

munge_block(blk, varargin{:});
%dec_order = get_var('dec_order', 'defaults', defaults, varargin{:});
n_inputs = get_var('n_inputs','defaults', defaults, varargin{:});
coeff = get_var('coeff', 'defaults', defaults, varargin{:});
n_bits = get_var('n_bits', 'defaults', defaults, varargin{:});
quantization = get_var('quantization', 'defaults', defaults, varargin{:});
add_latency = get_var('add_latency', 'defaults', defaults, varargin{:});
mult_latency = get_var('mult_latency', 'defaults', defaults, varargin{:});
conv_latency = get_var('conv_latency', 'defaults', defaults, varargin{:});
coeff_bit_width = get_var('coeff_bit_width', 'defaults', defaults, varargin{:});
coeff_bin_pt = get_var('coeff_bin_pt', 'defaults', defaults, varargin{:}); 
absorb_adders = get_var('absorb_adders', 'defaults', defaults, varargin{:});
adder_imp = get_var('adder_imp', 'defaults', defaults, varargin{:});

%default library state
if n_inputs == 0,
  delete_lines(blk);
  clean_blocks(blk);
  set_param(blk,'AttributesFormatString','');
  save_state(blk, 'defaults', defaults, varargin{:});
  clog('exiting filt_simple_init', 'trace');
  return;
end
delete_lines(blk);
% round coefficients to make sure rounding error doesn't prevent us from
% detecting symmetric coefficients
coeff_round = round(coeff * 1e16) * 1e-16;

% check that the number of inputs and coefficients are compatible
if mod(length(coeff) / n_inputs, 1) ~= 0,
    error_string = sprintf('The number of coefficients (%d) must be integer multiples of the number of inputs (%d).', length(coeff), n_inputs);
    clog(error_string, 'error');
    errordlg(error_string);
end

num_fir_col = length(coeff) / n_inputs;
coeff_sym = 0;
fir_col_type = 'fir_colm';

if mod(length(coeff),2) == 0 && mod(num_fir_col, 2)==0 
  if coeff_round(1:length(coeff)/2) == coeff_round(length(coeff):-1:length(coeff)/2+1),
    num_fir_col = num_fir_col / 2;
    fir_col_type = 'fir_dbl_colm';
    coeff_sym = 1;
  end
end

delete_lines(blk);

reuse_block(blk, 'sync_in', 'built-in/inport', ...
    'Position', [0 90*n_inputs+100 30 90*n_inputs+115], 'Port', num2str(n_inputs+1));

for i=1:n_inputs,
    reuse_block(blk, ['in',num2str(i)], 'built-in/inport', ...
        'Position', [0 90*i 30 90*i+15], 'Port', num2str(i));
end

% if we have only one input stream, then first stage of adders
% after multipliers are these adder_trees (otherwise inside cols)
if n_inputs == 1,
  first_stage_hdl_external = absorb_adders;  
else
  first_stage_hdl_external = 'off';
end

reuse_block(blk, 'real_sum', 'casper_library_misc/adder_tree', ...
    'Position', [200*num_fir_col+400 300 200*num_fir_col+460 num_fir_col*10+300], ...
    'n_inputs',num2str(num_fir_col),'latency',num2str(add_latency), ...
    'adder_imp', adder_imp, 'first_stage_hdl', first_stage_hdl_external);


for i=1:num_fir_col,
    blk_name = [fir_col_type,num2str(i)];
    prev_blk_name = [fir_col_type,num2str(i-1)];
    reuse_block(blk, blk_name, ['fir_lib/', fir_col_type]);
    set_param([blk,'/',blk_name], 'Position', [200*i+200 50 200*i+300 250]);
    set_param([blk,'/',blk_name], 'n_inputs', num2str(n_inputs));
    set_param([blk,'/',blk_name], 'coeff', mat2str(coeff(i*n_inputs:-1:(i-1)*n_inputs+1)));
    set_param([blk,'/',blk_name], 'mult_latency', num2str(mult_latency));
    set_param([blk,'/',blk_name], 'add_latency', num2str(add_latency));
    set_param([blk,'/',blk_name], 'coeff_bit_width', num2str(coeff_bit_width));
    set_param([blk,'/',blk_name], 'coeff_bin_pt', num2str(coeff_bin_pt));
	set_param([blk,'/',blk_name], 'adder_imp', adder_imp);
    set_param([blk,'/',blk_name], 'first_stage_hdl', absorb_adders);

    if i == 1,
        for j=1:n_inputs,
            add_line(blk, ['in',num2str(j),'/1'], [blk_name,'/',num2str(j)]);
        end    
    else
        for j=1:n_inputs,
            add_line(blk,[prev_blk_name,'/',num2str(j)],[blk_name,'/',num2str(j)]);
        end
    end

    if coeff_sym,
        add_line(blk,[blk_name,'/',num2str(n_inputs*2+1)],['real_sum/',num2str(i+1)]);
    else
        add_line(blk,[blk_name,'/',num2str(n_inputs+1)],['real_sum/',num2str(i+1)]);
    end
end

reuse_block(blk, 'shift1', 'xbsIndex_r4/Shift', ...
    'shift_dir', 'Left', 'shift_bits', '1', ...
    'Position', [200*num_fir_col+500 300 200*num_fir_col+530 315]);
reuse_block(blk, 'convert1', 'xbsIndex_r4/Convert', ...
    'Position', [200*num_fir_col+560 300 200*num_fir_col+590 315], ...
    'n_bits', num2str(n_bits), 'bin_pt', num2str(n_bits-1), 'arith_type', 'Signed  (2''s comp)', ...
    'latency', num2str(conv_latency), 'quantization', quantization);

reuse_block(blk, 'sync_out', 'built-in/outport', ...
    'Position', [200*num_fir_col+500 250 200*num_fir_col+530 265], 'Port', '1');
reuse_block(blk, 'dout1', 'built-in/outport', ...
    'Position', [200*num_fir_col+680 400 200*num_fir_col+710 415], 'Port', '2');
% delay of sync
if coeff_sym,
    % y(n) = sum(aix(n-i)) for i=0:N. sync is thus related to x(0)
    sync_latency = add_latency + mult_latency + ceil(log2(n_inputs))*add_latency + conv_latency;
else
    sync_latency = mult_latency + ceil(log2(n_inputs))*add_latency + conv_latency;
end

% if delay is greater than 17*3 then might as well use logic
% as using more than 3 SRL16s and sync_delay uses approx 3 
% (2 comparators, one counter) 

if sync_latency > 17*3,
  sync_delay_block = 'casper_library_delays/sync_delay';
else 
  sync_delay_block = 'xbsIndex_r4/Delay';
end

reuse_block(blk, 'delay', sync_delay_block, ...
    'Position', [60 90*n_inputs+100 90 90*n_inputs+130], ...
    'latency', num2str(sync_latency));

add_line(blk,'real_sum/2','shift1/1');
add_line(blk,'shift1/1','convert1/1');
add_line(blk, 'convert1/1', 'dout1/1');
add_line(blk,'sync_in/1','delay/1');
add_line(blk,'delay/1','real_sum/1');
add_line(blk,'real_sum/1','sync_out/1');

% backward links for symmetric coefficients
if coeff_sym,
    for i=1:num_fir_col,
        blk_name = [fir_col_type,num2str(i)];
        prev_blk_name = [fir_col_type,num2str(i-1)];
        if i ~= 1
            for j=1:n_inputs,
                add_line(blk,[blk_name,'/',num2str(n_inputs+j)],[prev_blk_name,'/',num2str(n_inputs+j)]);
            end
        end
    end

    for j=1:n_inputs,
        blk_name = [fir_col_type,num2str(num_fir_col)];
        add_line(blk,[blk_name,'/',num2str(j)],[blk_name,'/',num2str(n_inputs+j)]);
    end
end

% When finished drawing blocks and lines, remove all unused blocks.
clean_blocks(blk);

% Set attribute format string (block annotation)
annotation=sprintf('%d taps\n%d_%d r/i', length(coeff), n_bits, n_bits-1);
set_param(blk,'AttributesFormatString',annotation);

save_state(blk, 'defaults', defaults, varargin{:});

clog('exiting filt_simple_init', 'trace');