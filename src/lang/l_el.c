/* Last Translator: Pete_wg <pete_westg@yahoo.gr> */

#include "hbapilng.h"

static HB_LANG s_lang =
{
   {
      /* Identification */

      "el",                        /* ISO ID (2 chars) */
      "Greek",                     /* Name (in English) */
      "Ελληνικά",                  /* Name (in native language) */
      "EL",                        /* RFC ID */
      "UTF8",                      /* Codepage */
      "",                          /* Version */

      /* Month names */

      "Ιανουάριος",
      "Φεβρουάριος",
      "Μάρτιος",
      "Απρίλιος",
      "Μάιος",
      "Ιούνιος",
      "Ιούλιος",
      "Αύγουστος",
      "Σεπτέμβριος",
      "Οκτώβριος",
      "Νοέμβριος",
      "Δεκέμβριος",

      /* Day names */

      "Κυριακή",
      "Δευτέρα",
      "Τρίτη",
      "Τετάρτη",
      "Πέμπτη",
      "Παρασκευή",
      "Σάββατο",

      /* CA-Cl*pper compatible natmsg items */

      "Βάση δεδομένων    # Εγγραφών   Τελευταία ενημ. Μέγεθος",
      "Θέλετε περισσότερα παραδείγματα?",
      "Αρ. Σελίδας",
      "** Μερικό σύνολο **",
      "* Υποσύνολο *",
      "*** Σύνολο ***",
      "Εισ",
      "   ",
      "Ακυρη ημερ/νία",
      "Εύρος: ",
      " - ",
      "Ν/Ο",
      "ΑΚΥΡΗ ΕΚΦΡΑΣΗ",

      /* Error description names */

      "Αγνωστο λάθος",
      "Λάθος όρισμα",
      "Λάθος όρια",
      "Υπερχείλιση συμβολοσειράς",
      "Αριθμητική υπερχείλιση",
      "Μηδενικός διαιρέτης",
      "Αριθμητικό λάθος",
      "Συντακτικό λάθος",
      "Λειτουργία πολύ μπερδεμένη",
      "",
      "",
      "Χαμηλή μνήμη",
      "Απροσδιόριστη συνάρτηση /Undefined/",
      "Μη εξαγώγιμη μέθοδος",
      "Ανύπαρκτη μεταβλητή",
      "Το ψευδώνυμο /alias/ δεν υπάρχει",
      "Μη εξαγώγιμη μεταβλητή",
      "Ακυροι χαρακτήρες στο ψευδώνυμο /alias/",
      "Tο ψευδώνυμο /alias/ χρησιμοποιείται ήδη",
      "",
      "Λάθος δημιουργίας",
      "Λάθος ανοίγματος",
      "Λάθος κλεισίματος",
      "Λάθος ανάγνωσης",
      "Λάθος εγγραφής",
      "Λάθος εκτύπωσης",
      "",
      "",
      "",
      "",
      "Η λειτουργία δεν υποστηρίζεται",
      "Ξεπεράστηκε το όριο",
      "Ανιχνεύτηκε φθορά αρχείων",
      "Λανθασμένος τύπος δεδομένων",
      "Λανθασμένο πλάτος δεδομένων",
      "Η περιοχή-εργασίας δεν είναι σε χρήση",
      "Η περιοχή-εργασίας δεν είναι ταξινομημένη",
      "Απαιτείται αποκλειστική χρήση /Exclusive/",
      "Απαιτείται κλείδωμα",
      "Δεν επιτρέπεται η εγγραφή",
      "Αποτυχία κλειδώματος νέας εγγραφής /Append/",
      "Αποτυχία κλειδώματος",
      "",
      "",
      "",
      "Αποτυχία καταστροφής αντικειμένου",
      "πρόσβαση πίνακα",
      "καταχώριση σε πίνακα",
      "διασταση πίνακα",
      "δεν είναι πίνακας",
      "στη σύγκριση",

      /* Internal error names */

      "Μη αναστρέψιμο λάθος %d: ",
      "Αποτυχία επανόρθωσης λάθους",
      "Δεν υπάρχει ERRORBLOCK() για το λάθος",
      "Πάρα πολλές επαναλαμβανόμενες κλήσεις χειρισμού σφαλμάτων",
      "Ακυρη RDD ή αποτυχία φόρτωσης",
      "Ακυρος τύπος μεθόδου από %s",
      "Η συνάρτηση hb_xgrab δεν μπορεί να εκχωρήσει μνήμη",
      "Η συνάρτηση hb_xrealloc κλήθηκε με ένα δείκτη NULL",
      "Η συνάρτηση hb_xrealloc κλήθηκε με ένα άκυρο δείκτη",
      "Η συνάρτηση hb_xrealloc δεν μπορεί να εκχωρήσει μνήμη",
      "Η συνάρτηση hb_xfree κλήθηκε με ένα άκυρο δείκτη",
      "Η συνάρτηση hb_xfree κλήθηκε με ένα δείκτη NULL",
      "Αδυναμία εντοπισμού της εναρκτήριας διαδικασίας: '%s'",
      "Δεν υπάρχει εναρκτήρια διαδικασία",
      "Μη υσποστηριζόμενος VM opcode",
      "Συμβολοστοιχείο αναμενόταν από %s",
      "Ακυρος τύπος συμβόλου για self απο %s",
      "Αναμενόταν μπλοκ-κώδικα απο %s",
      "Ακυρος τύπος στοιχείου στοίβας επιχειρεί pop από %s",
      "Ελειπής ροή στοίβας /stack underflow/",
      "Ενα στοιχείο επιχειρούσε να αντιγραφεί στον εαυτό του από %s",
      "Ακυρο συμβολικό στοιχείο περάστηκε ως μεταβλητή μνήμης %s",
      "Υπερχείλιση buffer Μνήμης",
      "Η συνάρτηση hb_xgrab αιτήθηκε να διαθέσει μηδέν χαρακτήρες",
      "Η συνάρτηση hb_xrealloc αιτήθηκε να αλλάξει μέγεθος σε μηδέν χαρακτήρες",
      "Η συνάρτηση hb_xalloc αιτήθηκε να διαθέσει μηδέν χαρακτήρες",

      /* Texts */

      "DD/MM/YYYY",
      "Ν",
      "Ο"
   }
};

#define HB_LANG_ID      EL
#include "hbmsgreg.h"
