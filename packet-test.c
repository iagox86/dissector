#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <string.h>
#include <glib.h>

#include <epan/packet.h>
#include <epan/emem.h>
#include "packet-dns.h"
#include "packet-netbios.h"
#include "packet-tcp.h"
#include "packet-frame.h"
#include <epan/prefs.h>
#include <epan/strutil.h>

static int proto_test = -1;
static gint ett_test = -1;
static int hf_test1 = -1;
static int hf_test2 = -1;
static int hf_test3 = -1;

/* This is a temporary hack till I find a better way to fix the warning. */
#define TVB_WARNING_HACK tvb_get_guint8(tvb, 0); 

/* -- begin auto-generated prototypes -- */
guint32 get_test1_length(tvbuff_t *tvb);
guint32 get_test1_position(tvbuff_t *tvb);
guint8 get_test1_value(tvbuff_t *tvb);
guint32 get_test2_length(tvbuff_t *tvb);
guint32 get_test2_position(tvbuff_t *tvb);
guint16 get_test2_value(tvbuff_t *tvb);
guint32 get_test3_length(tvbuff_t *tvb);
guint32 get_test3_position(tvbuff_t *tvb);
guint32 get_test3_value(tvbuff_t *tvb);
/* -- end auto-generated prototypes -- */

/* -- begin auto-generated functions -- */
guint32 get_test1_length(tvbuff_t *tvb) {
  TVB_WARNING_HACK
  return 1;
}

guint32 get_test1_position(tvbuff_t *tvb) {
  guint32 position;
  position = 0;
  TVB_WARNING_HACK
  return position;
}
guint8 get_test1_value(tvbuff_t *tvb) {
  return tvb_get_guint8(tvb, get_test1_position(tvb));
}

guint32 get_test2_length(tvbuff_t *tvb) {
  TVB_WARNING_HACK
  return 2;
}

guint32 get_test2_position(tvbuff_t *tvb) {
  guint32 position;
  position = 1;
  TVB_WARNING_HACK
  return position;
}
guint16 get_test2_value(tvbuff_t *tvb) {
  return tvb_get_ntohs(tvb, get_test2_position(tvb));
}

guint32 get_test3_length(tvbuff_t *tvb) {
  TVB_WARNING_HACK
  return 4;
}

guint32 get_test3_position(tvbuff_t *tvb) {
  guint32 position;
  position = 3;
  TVB_WARNING_HACK
  return position;
}
guint32 get_test3_value(tvbuff_t *tvb) {
  return tvb_get_ntohl(tvb, get_test3_position(tvb));
}

/* -- end auto-generated functions -- */

static void dissect_test(tvbuff_t *tvb, packet_info *pinfo, proto_tree *tree)
{
  int            position = 0;
  guint16        id;

  /* This sets the string in the "Protocol" column. */
  col_set_str(pinfo->cinfo, COL_PROTOCOL, "test");

  /* Check if we should display the 'description' column, and set it if we do. */
  col_clear(pinfo->cinfo, COL_INFO);
  if(check_col(pinfo->cinfo, COL_INFO))
  {
    /* This is the column 'description' that's printed. */
    col_add_fstr(pinfo->cinfo, COL_INFO, "Test Protocol");
  }


  /* Only build the tree if we were passed one. */
  if (tree)
  {
    proto_item *ti                       = proto_tree_add_item(tree, proto_test, tvb, position, -1, FALSE);
    proto_tree *test_tree = proto_item_add_subtree(ti, ett_test);

    /* This is the value that will be displayed. */
    id = tvb_get_ntohs(tvb, 0);

    /* buffer, where to highlight, how long to highlight, which value to show. */
        proto_tree_add_uint(test_tree, hf_test1, tvb, get_test1_position(tvb), get_test1_length(tvb), get_test1_value(tvb));

    proto_tree_add_uint(test_tree, hf_test2, tvb, get_test2_position(tvb), get_test2_length(tvb), get_test2_value(tvb));

    proto_tree_add_uint(test_tree, hf_test3, tvb, get_test3_position(tvb), get_test3_length(tvb), get_test3_value(tvb));

  }
}

void proto_register_test(void)
{
  static hf_register_info hf_test[] = {
    { &hf_test1,  { "test1", "test.test1", FT_UINT8, BASE_HEX, NULL, 0x0, "test1", HFILL }},
    { &hf_test2,  { "test2", "test.test2", FT_UINT16, BASE_HEX, NULL, 0x0, "test2", HFILL }},
    { &hf_test3,  { "test3", "test.test3", FT_UINT32, BASE_HEX, NULL, 0x0, "test3", HFILL }},
  };

  static gint *ett[] = {
    &ett_test,
  };

  proto_test = proto_register_protocol("Test Protocol", "", ""); /* Name, shortname, abbrev. */
  proto_register_field_array(proto_test, hf_test, array_length(hf_test));

  proto_register_subtree_array(ett, array_length(ett));
}

void proto_reg_handoff_test(void)
{
  dissector_handle_t test_handle;

  test_handle = create_dissector_handle(dissect_test, proto_test);
  dissector_add_uint("udp.port", 137, test_handle);
}

