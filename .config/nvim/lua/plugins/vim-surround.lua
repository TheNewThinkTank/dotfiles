return {
  "tpope/vim-surround",
  event = "BufReadPre",
  config = function()
    -- vim-surround is ready to use, no additional config needed
    -- Use cases:
    -- cs"' - change " to '
    -- ds" - delete surrounding "
    -- ysiw" - add " around word
    -- yss" - add " around entire line
  end
}
