<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.sql.*, java.util.UUID, java.security.MessageDigest" %>
<%@ include file="../db.jsp" %>
<%
    request.setCharacterEncoding("UTF-8");

    String userId = request.getParameter("userid");
    String email = request.getParameter("email");
    String phone = request.getParameter("phonenum");
    String step = request.getParameter("step");
    String errorMsg = "";
    String successMsg = "";

    // === 1단계: 사용자 정보 인증(10분 제한) ===
    if (step == null) {
        Long blockUntil = (Long) session.getAttribute("findpw_block_until");
        long now = System.currentTimeMillis();
        if (blockUntil != null && now < blockUntil) {
            long remain = (blockUntil - now) / 1000;
            long min = remain / 60;
            long sec = remain % 60;
            errorMsg = "시도 횟수를 초과하여 10분간 차단됩니다.<br>("+min+"분 "+sec+"초 후 재시도 가능)";
        } else {
            Integer findTry = (Integer) session.getAttribute("findpw_find_try");
            if (findTry == null) findTry = 0;

            if (userId != null && email != null && phone != null) {
                PreparedStatement pstmt = null;
                ResultSet rs = null;
                try {
                    String sql = "SELECT * FROM user_table WHERE user_id = ? AND user_email = ? AND user_phonenum = ?";
                    pstmt = db_conn.prepareStatement(sql);
                    pstmt.setString(1, userId);
                    pstmt.setString(2, email);
                    pstmt.setString(3, phone);
                    rs = pstmt.executeQuery();

                    if (rs.next()) {
                        // 성공 시 세션 초기화 및 otp 발급
                        session.setAttribute("findpw_userid", userId);
                        session.setAttribute("findpw_email", email);
                        session.setAttribute("findpw_phone", phone);
                        session.setAttribute("findpw_otp", "123456");
                        session.setAttribute("findpw_otpattempt", 0);
                        session.removeAttribute("findpw_find_try");
                        session.removeAttribute("findpw_block_until");
                    } else {
                        findTry++;
                        session.setAttribute("findpw_find_try", findTry);
                        if (findTry > 5) {
                            long banUntil = now + (10 * 60 * 1000); // 10분
                            session.setAttribute("findpw_block_until", banUntil);
                            errorMsg = "시도 횟수를 초과하여 10분간 차단됩니다.";
                        } else {
                            errorMsg = "입력한 정보가 일치하지 않습니다. 다시 확인해주세요. (" + (6-findTry) + "회 남음)";
                        }
                    }
                } finally {
                    if (rs != null) try { rs.close(); } catch (Exception ignore) {}
                    if (pstmt != null) try { pstmt.close(); } catch (Exception ignore) {}
                }
            }
        }
    }
    // === 2단계: OTP 인증 처리 ===
    else if ("otp".equals(step)) {
        String otpInput = request.getParameter("otp");
        String sessionOtp = (String) session.getAttribute("findpw_otp");
        Integer otpTry = (Integer) session.getAttribute("findpw_otpattempt");
        if (otpTry == null) otpTry = 0;
        otpTry++;
        session.setAttribute("findpw_otpattempt", otpTry);

        if (otpTry > 5) {
            errorMsg = "OTP 인증 시도 횟수를 초과했습니다. 처음부터 다시 진행해주세요.";
            session.removeAttribute("findpw_userid");
            session.removeAttribute("findpw_email");
            session.removeAttribute("findpw_phone");
            session.removeAttribute("findpw_otp");
            session.removeAttribute("findpw_otpattempt");
        } else if ("123456".equals(otpInput)) {
            // 임시비밀번호 생성 및 해싱
            String tempPw = UUID.randomUUID().toString().substring(0, 8);
            String hashPw = "";
            try {
                MessageDigest md = MessageDigest.getInstance("SHA-512");
                byte[] hashed = md.digest(tempPw.getBytes("UTF-8"));
                StringBuilder sb = new StringBuilder();
                for (byte b : hashed) sb.append(String.format("%02x", b));
                hashPw = sb.toString();
            } catch(Exception e){ hashPw = tempPw; }
            String updateSql = "UPDATE user_table SET user_password = ? WHERE user_id = ?";
            PreparedStatement updateStmt = db_conn.prepareStatement(updateSql);
            updateStmt.setString(1, hashPw);
            updateStmt.setString(2, (String)session.getAttribute("findpw_userid"));
            updateStmt.executeUpdate();
            updateStmt.close();

            // 세션 정보 제거
            session.removeAttribute("findpw_otp");
            session.removeAttribute("findpw_otpattempt");
            session.removeAttribute("findpw_userid");
            session.removeAttribute("findpw_email");
            session.removeAttribute("findpw_phone");
            successMsg = "임시 비밀번호는 <b>[" + tempPw + "]</b> 입니다.<br>로그인 후 반드시 변경해주세요.";
        } else {
            errorMsg = "잘못된 OTP 코드입니다. 다시 입력해주세요. (" + (6-otpTry) + "회 남음)";
        }
    }
%>


<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Sharks - 비밀번호 찾기</title>
    <link rel="stylesheet" href="../style.css">
    <link rel="stylesheet" href="find_style.css">
    <link rel="icon" href="/img/sharks2.jpg" type="image/jpeg">
</head>
<body style="background:#97d6f5;">
<%
    // 1단계: 정보 입력 실패 (OTP 인증 단계의 에러 포함!)
    if ((errorMsg != null && !errorMsg.isEmpty() && step == null) ||
        (errorMsg != null && !errorMsg.isEmpty() && "otp".equals(step))) {
%>
    <div class="modal-bg">
      <div class="modal-box">
        <h2>비밀번호 찾기</h2>
        <div class="error-msg"><%= errorMsg %></div>
        <button onclick="location.href='find_account.jsp'">돌아가기</button>
      </div>
    </div>
<%
    // OTP 인증 단계
    } else if ((step == null && errorMsg.isEmpty()) || ("otp".equals(step) && (errorMsg.isEmpty() && successMsg.isEmpty()))) {
%>
    <div class="center-modal-container">
    <div class="center-modal-box">
        <h1>휴대폰 인증</h1>
        <div class="desc">
            휴대폰 번호로 전송된<br>
            <b>6자리 OTP</b>를 입력하세요.<br>
            <small>(실제 전송 없이 <b>123456</b> 입력 시 성공)</small>
        </div>
        <form method="POST" action="find_pw_proc.jsp" style="margin-top: 20px;">
            <!-- ★ 히든 필드 추가! ★ -->
            <input type="hidden" name="step" value="otp"/>
            <input type="text" name="otp" maxlength="6" placeholder="OTP" required class="modal-input"/>
            <button type="submit" class="modal-btn">인증</button>
        </form>
    </div>
</div>
<%
    // 성공 메시지 (임시비밀번호)
    } else if (successMsg != null && !successMsg.isEmpty()) {
%>
    <div class="center-modal-container">
    <div class="center-modal-box">
        <h1>비밀번호 찾기 완료</h1>
        <div class="desc">
            <%= successMsg %>
        </div>
        <form method="GET" action="../passlogic/login.jsp" style="margin-top: 20px;">
            <button type="submit" class="modal-btn">로그인하러 가기</button>
        </form>
    </div>
</div>
<%
    }
%>
</body>
</html>
