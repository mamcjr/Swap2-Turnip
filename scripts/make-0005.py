"""Writes patch 0005 into the mesa-rel worktree (run inside WSL): ir3's lowering of an arbitrary-index subgroup shuffle loops over the distinct relative offsets of
its lanes (one shfl a pass) and, in the same pass, over the distinct absolute source lanes (one movs: read_invocation with a uniform lane), so a lane is served by
whichever matches first. A broadcast from a lane each 32-lane half picks (the translator's form of NVIDIA's SHFL.IDX of a warp-uniform lane, 64-lane subgroups) takes
at most two passes instead of up to 32; a rotate-like pattern keeps its relative passes."""
import re
import sys
from pathlib import Path

f = Path.home() / 'turnip-swap2/mesa-rel/src/freedreno/ir3/ir3_lower_subgroups.c'
s = f.read_text()

old_fn_head = '''static nir_def *
make_shuffle_uniform(nir_builder *b, nir_def *val, nir_def *index,
                     nir_intrinsic_op op)
{'''
new_fn_head = '''static nir_def *
make_shuffle_uniform(nir_builder *b, nir_def *val, nir_def *index,
                     nir_intrinsic_op op, nir_def *abs_index)
{'''
assert s.count(old_fn_head) == 1
s = s.replace(old_fn_head, new_fn_head)

old_body = '''      nir_if *nif = nir_push_if(b, nir_ieq(b, index, next_index));
      {
         nir_store_var(b, result, shuffled, 1);
         nir_store_var(b, done, nir_imm_true(b), 1);
      }
      nir_pop_if(b, nif);
'''
new_body = '''      nir_if *nif = nir_push_if(b, nir_ieq(b, index, next_index));
      {
         nir_store_var(b, result, shuffled, 1);
         nir_store_var(b, done, nir_imm_true(b), 1);
      }
      nir_pop_if(b, nif);

      if (abs_index) {
         /* Swap2-Turnip: the same pass also serves every pending lane that
          * reads the absolute lane the first pending lane reads (a movs with a
          * uniform lane), so a shuffle with few distinct source lanes but many
          * distinct relative offsets (a broadcast from a lane chosen per 32-lane
          * half) takes one pass per source lane.
          */
         nir_def *next_abs = nir_read_invocation_cond_ir3(
            b, abs_index->bit_size, abs_index, nir_inot(b, nir_load_var(b, done)));
         next_abs->divergent = false;
         nir_def *read = nir_read_invocation(b, val, next_abs);

         nir_if *nif2 = nir_push_if(
            b, nir_iand(b, nir_inot(b, nir_load_var(b, done)),
                        nir_ieq(b, abs_index, next_abs)));
         {
            nir_store_var(b, result, read, 1);
            nir_store_var(b, done, nir_imm_true(b), 1);
         }
         nir_pop_if(b, nif2);
      }
'''
assert s.count(old_body) == 1
s = s.replace(old_body, new_body)

old_lower = '''   nir_def *index = intrin->src[1].ssa;

   if (intrin->intrinsic == nir_intrinsic_shuffle) {'''
new_lower = '''   nir_def *index = intrin->src[1].ssa;
   nir_def *abs_index = NULL;

   if (intrin->intrinsic == nir_intrinsic_shuffle) {
      abs_index = index;'''
assert s.count(old_lower) == 1
s = s.replace(old_lower, new_lower)

old_call = '''   return make_shuffle_uniform(b, val, index, intrin->intrinsic);'''
new_call = '''   return make_shuffle_uniform(b, val, index, intrin->intrinsic, abs_index);'''
assert s.count(old_call) == 1
s = s.replace(old_call, new_call)
f.write_text(s)
print('ok')

# only where the GPU has movs (read_invocation with a lane): the absolute passes are a movs each
s = f.read_text()
old = '''   if (intrin->intrinsic == nir_intrinsic_shuffle) {
      abs_index = index;'''
new = '''   if (intrin->intrinsic == nir_intrinsic_shuffle) {
      const struct ir3_shader *shader = data;
      if (shader->compiler->info->props.has_movs)
         abs_index = index;'''
assert s.count(old) == 1; s = s.replace(old, new)
old = '''   return nir_shader_lower_instructions(nir, filter_shuffle, lower_shuffle,
                                        NULL);'''
new = '''   return nir_shader_lower_instructions(nir, filter_shuffle, lower_shuffle,
                                        shader);'''
assert s.count(old) == 1; s = s.replace(old, new)
f.write_text(s)
print('guarded')
