#include "control_surface_wrapper.h"
#include "control_surface.h"
#ifndef _CSURF_H_
#define _CSURF_H_
#include <stdio.h>
#include "../reaper_plugin.h"
#include "../../WDL/localize/localize.h"

#include "../../WDL/db2val.h"
#include "../../WDL/wdlstring.h"
#include "../../WDL/wdlcstring.h"
#include "../../WDL/win32_utf8.h"
#include "resource.h"
#include <new>
#include "../../WDL/swell/swell-types.h"

static void parseParms(const char *str, int parms[4])
{
  parms[0] = 0;
  parms[1] = 9;
  parms[2] = parms[3] = -1;

  const char *p = str;
  if (p)
  {
    int x = 0;
    while (x < 4)
    {
      while (*p == ' ')
        p++;
      if ((*p < '0' || *p > '9') && *p != '-')
        break;
      parms[x++] = atoi(p);
      while (*p && *p != ' ')
        p++;
    }
  }
}
static WDL_DLGRET dlgProc(HWND hwndDlg, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
  switch (uMsg)
  {
  case WM_INITDIALOG:
  {
    int parms[4];
    parseParms((const char *)lParam, parms);

    ShowWindow(GetDlgItem(hwndDlg, IDC_EDIT1), SW_HIDE);
    ShowWindow(GetDlgItem(hwndDlg, IDC_EDIT1_LBL), SW_HIDE);
    ShowWindow(GetDlgItem(hwndDlg, IDC_EDIT2), SW_HIDE);
    ShowWindow(GetDlgItem(hwndDlg, IDC_EDIT2_LBL), SW_HIDE);
    ShowWindow(GetDlgItem(hwndDlg, IDC_EDIT2_LBL2), SW_HIDE);

    WDL_UTF8_HookComboBox(GetDlgItem(hwndDlg, IDC_COMBO2));
    WDL_UTF8_HookComboBox(GetDlgItem(hwndDlg, IDC_COMBO3));

    int n = GetNumMIDIInputs();
    int x = SendDlgItemMessage(hwndDlg, IDC_COMBO2, CB_ADDSTRING, 0, (LPARAM)__LOCALIZE("None", "csurf"));
    SendDlgItemMessage(hwndDlg, IDC_COMBO2, CB_SETITEMDATA, x, -1);
    x = SendDlgItemMessage(hwndDlg, IDC_COMBO3, CB_ADDSTRING, 0, (LPARAM)__LOCALIZE("None", "csurf"));
    SendDlgItemMessage(hwndDlg, IDC_COMBO3, CB_SETITEMDATA, x, -1);
    for (x = 0; x < n; x++)
    {
      char buf[512];
      if (GetMIDIInputName(x, buf, sizeof(buf)))
      {
        int a = SendDlgItemMessage(hwndDlg, IDC_COMBO2, CB_ADDSTRING, 0, (LPARAM)buf);
        SendDlgItemMessage(hwndDlg, IDC_COMBO2, CB_SETITEMDATA, a, x);
        if (x == parms[2])
          SendDlgItemMessage(hwndDlg, IDC_COMBO2, CB_SETCURSEL, a, 0);
      }
    }
    n = GetNumMIDIOutputs();
    for (x = 0; x < n; x++)
    {
      char buf[512];
      if (GetMIDIOutputName(x, buf, sizeof(buf)))
      {
        int a = SendDlgItemMessage(hwndDlg, IDC_COMBO3, CB_ADDSTRING, 0, (LPARAM)buf);
        SendDlgItemMessage(hwndDlg, IDC_COMBO3, CB_SETITEMDATA, a, x);
        if (x == parms[3])
          SendDlgItemMessage(hwndDlg, IDC_COMBO3, CB_SETCURSEL, a, 0);
      }
    }
  }
  break;
  case WM_USER + 1024:
    if (wParam > 1 && lParam)
    {
      char tmp[512];

      int indev = -1, outdev = -1;
      int r = SendDlgItemMessage(hwndDlg, IDC_COMBO2, CB_GETCURSEL, 0, 0);
      if (r != CB_ERR)
        indev = SendDlgItemMessage(hwndDlg, IDC_COMBO2, CB_GETITEMDATA, r, 0);
      r = SendDlgItemMessage(hwndDlg, IDC_COMBO3, CB_GETCURSEL, 0, 0);
      if (r != CB_ERR)
        outdev = SendDlgItemMessage(hwndDlg, IDC_COMBO3, CB_GETITEMDATA, r, 0);

      snprintf(tmp, sizeof(tmp), "0 0 %d %d", indev, outdev);
      lstrcpyn((char *)lParam, tmp, wParam);
    }
    break;
  }
  return 0;
}

extern "C"
{

  C_ControlSurface ControlSurface_Create()
  {
    return new (std::nothrow) ZigControlSurface();
  }

  void ControlSurface_Destroy(C_ControlSurface instance)
  {
    delete static_cast<ZigControlSurface *>(instance);
  }

  HWND configFunc(const char *type_string, HWND parent, const char *initConfigString)
  {
    return CreateDialogParam(g_hInst, MAKEINTRESOURCE(IDD_SURFACEEDIT_MCU), parent, dlgProc, (LPARAM)initConfigString);
  }
}
#endif
