ARCHY_MIGRATIONS_STATE_PATH=~/.local/state/archy/migrations
mkdir -p $ARCHY_MIGRATIONS_STATE_PATH

for file in ~/.local/share/archy/migrations/*.sh; do
  touch "$ARCHY_MIGRATIONS_STATE_PATH/$(basename "$file")"
done
