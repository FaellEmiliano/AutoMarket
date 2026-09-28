extends Node

signal execution_finished(output)

signal execution_failed(errors)

signal send_output(args)

signal catch_input(id)

signal redraw_buttons()

signal end_client(result)

signal update_money(num)

signal open_client_terminal()

signal update_context(context)

signal get_estoque()

signal send_estoque(estoque)

signal send_debug(text)

signal secret_menu_unlocked()

signal player_notification(message)

signal conversation_message_shown(speaker, text)
