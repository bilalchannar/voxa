# Voxa — Profile / Privacy / Settings QA Report

**Date:** 2026-08-12
**Scope:** Profile screen ke saare options — Privacy (Last Seen, Profile Photo, About, Online Status, Status), Chat customization, Notifications, Appearance, Storage, Security.
**Method:** Static code trace (Flutter SDK sandbox mein available nahi tha, so `flutter analyze`/tests run nahi ho sake — verification pura source-trace se hui: save-path + enforcement-path dono).

> **Key idea:** Har setting ke 2 halve hote hain — (1) **Save** hona (Firestore mein likhna) aur (2) **Enforce** hona (dusre user ko actually farq padna). Zyada bugs enforcement side pe hain, save side theek hai.

---

## 1. Privacy options — verdict table

| Option | Save | Enforce (Nobody / "only me") | "My Contacts" | Verdict |
|---|---|---|---|---|
| **Profile Photo** | ✅ | ✅ hides everywhere (`canSeePhoto` chat list, header, contacts, calls, status) | ⚠️ == Everyone | **Working** |
| **Status** | ✅ | ✅ UI-level: sirf aap dekhte ho, doosron ki app hide kar deti hai | ⚠️ == Everyone | **Working (UI), caveats** |
| **Last Seen** | ✅ | ✅ chat header mein hide (inline check) | ⚠️ == Everyone | **Working (fragile)** |
| **Online Status** | ✅ | ⚠️ chat header mein hide, **lekin chat LIST ka green dot leak karta hai** | ⚠️ == Everyone | **Buggy (leak)** |
| **About** | ✅ | ❌ kahin enforce nahi (`canSeeAbout` kabhi call hi nahi hota) | ⚠️ == Everyone | **Not enforced** |

Save path sab ke liye theek hai: `PrivacyScreen._edit` → `ProfileViewModel.updatePrivacy` → `FirebaseService.updatePrivacy` → `users/{uid}.privacy.<field>`. StreamBuilder live reflect karta hai. ✅

---

## 2. Aapka specific sawaal — "Status only for me → only for me show ho"

**Jawaab: Haan, UI level pe yeh kaam karta hai.** ✅

- Upload waqt `status_view.dart:97` profile ka `privacy['status']` padh kar status doc pe stamp karta hai.
- `status_view.dart:136-140` doosron ke `privacy == 'nobody'` waale status hide karta hai, aur aapka apna status (`s.uid == myUid`) hamesha dikhta hai.

**Lekin 3 zaroori caveats:**

1. **Truly private nahi hai (server side).** `firestore.rules:74-75` har signed-in user ko **saare** status docs read karne deta hai, aur `StatusService.getStatuses()` sabhi statuses download karta hai — privacy sirf UI mein filter hoti hai. Modified/2nd client "nobody" status ka data phir bhi dekh sakta hai.
2. **Purane status retroactively hide nahi hote.** Agar aapne pehle "Everyone" pe status daala aur baad mein setting "Nobody" ki, to purana status "everyone" hi rahega. Sirf **naye** status new setting follow karte hain.
3. **"My Contacts" == "Everyone"** status ke liye (sirf `nobody` filter hota hai).

---

## 3. Bugs (priority order)

### 🔴 P1 — Online Status "Nobody" chat list mein leak
**File:** `lib/widgets/chat/chats_view.dart:310-312`
```dart
final isOnline = isGroup
    ? false
    : (otherUser?.isOnline ?? false);   // ❌ onlineStatus privacy check nahi
```
Chat ke andar (`chat_screen.dart:541-544`) to `onlineStatus != 'nobody'` check hota hai, par chat LIST ka green dot raw `isOnline` use karta hai. Natija: user "Online Status = Nobody" set kare, phir bhi chat list mein green dot dikhta hai.
**Fix:** `otherUser?.canSeeOnlineStatus(uid) == true && otherUser?.isOnline == true`.

### 🔴 P1 — "My Contacts" option kuch nahi karta
**Files:** `user_profile.dart:85-107`, `status_view.dart:138`, `chat_screen.dart:541-542`
Saare privacy checks `!= 'nobody'` hain, aur app mein koi contacts/friends graph hi nahi (`getAllUsers()` sabko return karta hai). Isliye teenon options mein se "My Contacts" bilkul "Everyone" jaisa behave karta hai — koi restriction nahi.
**Fix:** ya to contact-graph introduce karo, ya "My Contacts" option UI se hata do jab tak enforce na ho (users ko galat security feeling na ho).

### 🟠 P2 — About "Nobody" enforce nahi hota
**Files:** `user_profile.dart:97` (`canSeeAbout` defined but **never called**), `contact_tile.dart:55` (about bina check ke fallback subtitle mein dikh sakta hai).
**Fix:** jahan doosre user ka about dikhe wahan `canSeeAbout(currentUid)` gate lagao.

### 🟠 P2 — Status privacy client-side only + rules loose
**File:** `firestore.rules:74-79`, `status_service.dart:44-60`
Upar caveat #1 dekho. Sach mein private chahiye to rules mein privacy/allowed-viewers enforce karni padegi (ya query ko privacy pe filter karna).

### 🟡 P3 — Dead settings (save hote hain, kaam nahi karte)
- **Enter key sends** — `chat_settings_screen.dart:146` save karta hai, par poore `lib/` mein `enterKeySends` kahin read nahi hota. Message composer isse use nahi karta → toggle ka koi asar nahi.
- **Media visibility** — `chat_settings_screen.dart:154` save hota hai, kahin read nahi hota → koi asar nahi.
**Fix:** ya wire karo, ya UI se hata do (Storage screen ki tarah honest "future" disclaimer bhi de sakte ho).

### 🟡 P3 — Code hygiene: dead helper methods
`canSeeLastSeen`, `canSeeAbout`, `canSeeOnlineStatus` defined hain par sirf `canSeePhoto` actual mein call hota hai. Enforcement do jagah do tareeqe se (helper vs inline) hoti hai — inconsistent aur future bugs ka risk.

---

## 4. Jo cheezein sahi kaam kar rahi hain ✅

- **Profile Photo privacy** — Nobody karo to photo har jagah hide (initial dikhta hai). Consistent. ✅
- **Chat font size** (Small/Medium/Large) — save + live preview + real chat bubbles pe apply (`chat_screen.dart:819, 952`). ✅
- **Chat wallpaper** (color swatches) — real chat background pe apply (`chat_screen.dart:816-822`). ✅
- **Appearance / Theme** (Light/Dark/System) — persist + app-wide apply + startup pe load (`theme_controller.dart`, `main.dart:48`). ✅
- **Notifications** (message/call/sound/vibration) — **foreground** notifications mein enforce hote hain (`notification_service.dart:120-153`). ✅
  - ⚠️ Caveat: app killed/background mein FCM `notification` payload system draw karta hai — ye toggles tab bypass ho sakte hain (data-only payload + background handler chahiye).
- **Storage & data** (auto-download) — preferences save hoti hain; code mein imaandari se likha hai ki abhi download layer se wired nahi (by-design placeholder). ✅ (disclosed)
- **Security screen** — read-only info (phone, provider, UID copy, created date), theek. ✅

---

## 5. Summary

Aapki asli chinta (status "only for me") **UI pe theek chalti hai**. Sabse zaroori 2 cheezein jo attention maangti hain: **(1)** online status ka green-dot leak chat list mein, aur **(2)** "My Contacts" option jo kisi bhi privacy setting mein actually kuch nahi karta. Baaki: About enforce nahi hota, aur do chat toggles (Enter-to-send, Media visibility) dead hain.
