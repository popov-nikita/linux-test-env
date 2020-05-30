___comma  := ,
___squote := '
___empty  :=
___space  := $(___empty) $(___empty)
___escsq   = $(subst $(___squote),'\$(___squote)',$(1))

___not       = $(if $(1),$(___empty),___not)
___fixed_cmd = $(strip $(cmd_$(1)))
___o_target  = $(filter %.o,$(___fixed_cmd))
___c_target  = $(filter %.c,$(___fixed_cmd))
___xc_target = $(filter %$(patsubst %.c,%,$(notdir $(___c_target))),$(___fixed_cmd))
___S_target  = $(filter %.S,$(___fixed_cmd))
___xS_target = $(filter %$(patsubst %.S,%,$(notdir $(___S_target))),$(___fixed_cmd))
___is_c_o = $(and $(___c_target),$(___o_target),$(findstring -o$(___space)$(___o_target),$(___fixed_cmd)),$(filter -c,$(___fixed_cmd)))
___is_c_x = $(and $(___c_target),$(___xc_target),$(findstring -o$(___space)$(___xc_target),$(___fixed_cmd)),$(call ___not,$(filter -c,$(___fixed_cmd))))
___is_S_o = $(and $(___S_target),$(___o_target),$(findstring -o$(___space)$(___o_target),$(___fixed_cmd)),$(filter -c,$(___fixed_cmd)))
___is_S_x = $(and $(___S_target),$(___xS_target),$(findstring -o$(___space)$(___xS_target),$(___fixed_cmd)),$(call ___not,$(filter -c,$(___fixed_cmd))))

___classify_msg_c_o := .c -> .o target
___classify_msg_c_x := .c -> executable target
___classify_msg_S_o := .S -> .o target
___classify_msg_S_x := .S -> executable target
___classify_msg_unk := Unknown

___diagnostic_msg = printf '  $(call ___escsq,From$(___space)%s$(___space)class$(___space)=$(___space)'%s'\n)' "$${___MAKE_VARIABLE}" '$(call ___escsq,$(1))'

___remove_cf = $(filter-out -c,$(___fixed_cmd))
___remove_MD = $(filter-out -Wp$(___comma)-MD$(___comma)%,$(___remove_cf))
___remove_o  = $(strip $(subst -o$(___space)$(___o_target),$(___empty),$(___remove_MD)))
___remove_xc = $(strip $(subst -o$(___space)$(___xc_target),$(___empty),$(___remove_MD)))
___remove_xS = $(strip $(subst -o$(___space)$(___xS_target),$(___empty),$(___remove_MD)))
___CPP_options  := -E -P -C
___add_output_oc = $(___remove_o) -o $(basename $(___o_target)).___cpp___.c $(___CPP_options)
___add_output_xc = $(___remove_xc) -o $(___xc_target).___cpp___.c $(___CPP_options)
___add_output_oS = $(___remove_o) -o $(basename $(___o_target)).___cpp___.S $(___CPP_options)
___add_output_xS = $(___remove_xS) -o $(___xS_target).___cpp___.S $(___CPP_options)

___action_c_o = $(call ___diagnostic_msg,$(___classify_msg_c_o)); $(___add_output_oc); echo '/* $(call ___escsq,$(___add_output_oc)) */' >> $(basename $(___o_target)).___cpp___.c; echo '  CPP     $(basename $(___o_target)).___cpp___.c'
___action_c_x = $(call ___diagnostic_msg,$(___classify_msg_c_x)); $(___add_output_xc); echo '/* $(call ___escsq,$(___add_output_xc)) */' >> $(___xc_target).___cpp___.c; echo '  CPP     $(___xc_target).___cpp___.c'
___action_S_o = $(call ___diagnostic_msg,$(___classify_msg_S_o)); $(___add_output_oS); echo '/* $(call ___escsq,$(___add_output_oS)) */' >> $(basename $(___o_target)).___cpp___.S; echo '  CPP     $(basename $(___o_target)).___cpp___.S'
___action_S_x = $(call ___diagnostic_msg,$(___classify_msg_S_x)); $(___add_output_xS); echo '/* $(call ___escsq,$(___add_output_xS)) */' >> $(___xS_target).___cpp___.S; echo '  CPP     $(___xS_target).___cpp___.S'
___action_def = $(call ___diagnostic_msg,$(___classify_msg_unk))
___classify   = $(if $(___is_c_o),$(___action_c_o),$(if $(___is_c_x),$(___action_c_x),$(if $(___is_S_o),$(___action_S_o),$(if $(___is_S_x),$(___action_S_x),$(___action_def)))))

define if_changed
	@export ___MAKE_VARIABLE='if_changed'; $(___classify)
	$(___tmp_if_changed)
endef

define if_changed_dep
	@export ___MAKE_VARIABLE='if_changed_dep'; $(___classify)
	$(___tmp_if_changed_dep)
endef

define if_changed_rule
	@export ___MAKE_VARIABLE='if_changed_rule'; $(___classify)
	$(___tmp_if_changed_rule)
endef
